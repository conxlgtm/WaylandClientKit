import WaylandClient
import WaylandGPUPreview

package protocol WaylandGraphicsManagedWindow: Sendable {
    var id: WindowID { get }
    var geometry: SurfaceGeometry { get async throws }
    var isClosed: Bool { get async throws }

    func prepareGraphicsPreviewPresentation(
        timeoutMilliseconds: Int32
    ) async throws -> SurfaceGeometry

    func show(
        timeoutMilliseconds: Int32,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws

    func redraw(
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws

    func close() async
}

extension WaylandGraphicsManagedWindow {
    package func prepareGraphicsPreviewPresentation(
        timeoutMilliseconds _: Int32
    ) async throws -> SurfaceGeometry {
        try await geometry
    }
}

extension Window: WaylandGraphicsManagedWindow {}

package struct WaylandGraphicsManagedGPUClearFrameSubmission: Sendable {
    let color: GPUClearColor
    let metadata: SurfaceCommitMetadata
    let geometry: SurfaceGeometry
    let synchronization: GPUBufferSubmissionSynchronization
    let pacing: SurfacePacingConstraint
    let requestPresentationFeedback: Bool
}

package protocol WaylandGraphicsManagedGPUBacking: AnyObject {
    var runtimePathSnapshot: GPURuntimePathSnapshot { get }
    var surfaceCapabilities: SurfaceCapabilitySnapshot? { get }

    func close()

    func submitClearFrame(
        _ submission: WaylandGraphicsManagedGPUClearFrameSubmission
    ) async throws(ManagedGPUPreviewBackingError) -> GPUWindowPresentedFrame
}

extension ManagedGPUPreviewBacking: WaylandGraphicsManagedGPUBacking {
    package func submitClearFrame(
        _ submission: WaylandGraphicsManagedGPUClearFrameSubmission
    ) async throws(ManagedGPUPreviewBackingError) -> GPUWindowPresentedFrame {
        try await submitClearFrame(
            color: submission.color,
            metadata: submission.metadata,
            geometry: submission.geometry,
            synchronization: submission.synchronization,
            pacing: submission.pacing,
            requestPresentationFeedback: submission.requestPresentationFeedback
        )
    }
}

// swiftlint:disable:next type_body_length
package actor WaylandGraphicsWindowBackingStorage {
    let window: any WaylandGraphicsManagedWindow
    private let configuration: WaylandGraphicsConfiguration
    private let managedGPUBacking: (any WaylandGraphicsManagedGPUBacking)?
    private var backingRuntimePath: WaylandGraphicsRuntimePath
    private var leaseState = WaylandGraphicsFrameLeaseState()

    package init(
        window backingWindow: any WaylandGraphicsManagedWindow,
        runtimePath initialRuntimePath: WaylandGraphicsRuntimePath,
        configuration backingConfiguration: WaylandGraphicsConfiguration = .default,
        managedGPUBacking gpuBacking: (any WaylandGraphicsManagedGPUBacking)? = nil
    ) {
        window = backingWindow
        configuration = backingConfiguration
        managedGPUBacking = gpuBacking
        backingRuntimePath = initialRuntimePath
    }

    func runtimePath() throws -> WaylandGraphicsRuntimePath {
        try leaseState.requireNotClosed()
        return backingRuntimePath
    }

    package func nextFrame() async throws -> WaylandGraphicsFrameLease {
        try await nextFrame(afterWindowCheck: noGraphicsPreviewSubmissionHook)
    }

    func nextFrame(
        afterWindowCheck: @Sendable () async -> Void
    ) async throws -> WaylandGraphicsFrameLease {
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()
        await afterWindowCheck()
        try leaseState.requireNotClosed()

        let geometry: SurfaceGeometry
        do {
            geometry = try await window.geometry
            try leaseState.requireNotClosed()
        } catch {
            throw graphicsError(for: error, stage: .frameGeometry)
        }
        let leaseID = try leaseState.issueLease()
        return WaylandGraphicsFrameLease(
            id: leaseID,
            size: geometry.bufferSize,
            runtimePath: backingRuntimePath,
            storage: self
        )
    }

    func submit(
        leaseID: WaylandGraphicsFrameLeaseID,
        frame: WaylandGraphicsSubmittedFrame
    ) async throws -> WaylandGraphicsFrameResult {
        try await submit(
            leaseID: leaseID,
            frame: frame,
            beforeSubmissionEffect: noThrowingGraphicsPreviewSubmissionHook,
            afterSubmissionEffect: noGraphicsPreviewSubmissionHook
        )
    }

    func submit(
        leaseID: WaylandGraphicsFrameLeaseID,
        frame: WaylandGraphicsSubmittedFrame,
        beforeSubmissionEffect: @Sendable () async throws -> Void,
        afterSubmissionEffect: @Sendable () async throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()
        try await prepareManagedGPUInitialConfigureIfNeeded(leaseID: leaseID)

        let geometry = try await submissionGeometry(for: leaseID)
        try frame.validateManagedPreviewSupport(
            configuration: configuration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let operation = try leaseState.prepareSubmission(leaseID: leaseID)
        var stage = WaylandGraphicsSubmissionStage.submissionPreparation
        do {
            try await beforeSubmissionEffect()
            stage = .frameSubmission
            try await submitFrame(
                frame,
                operation: operation,
                geometry: geometry
            )
            stage = .submissionCompletion
            try await afterSubmissionEffect()
            try leaseState.finishSubmission()
            return frameResult(
                operation: operation,
                size: geometry.bufferSize,
                metadata: frame.metadata
            )
        } catch {
            leaseState.failSubmission()
            throw graphicsError(for: error, stage: stage, operation: operation)
        }
    }

    func submitSoftware(
        leaseID: WaylandGraphicsFrameLeaseID,
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()

        let geometry = try await submissionGeometry(for: leaseID)
        try frameMetadata.validateManagedPreviewSupport(
            configuration: configuration,
            capabilities: backingRuntimePath.capabilities,
            geometry: geometry
        )
        let operation = try leaseState.prepareSubmission(leaseID: leaseID)
        var stage = WaylandGraphicsSubmissionStage.submissionPreparation
        do {
            stage = .frameSubmission
            try await submitSoftwareFrame(
                metadata: frameMetadata,
                operation: operation,
                draw
            )
            stage = .submissionCompletion
            try leaseState.finishSubmission()
            return frameResult(
                operation: operation,
                size: geometry.bufferSize,
                metadata: frameMetadata
            )
        } catch {
            leaseState.failSubmission()
            if let drawError = WaylandGraphicsErrorMapper.callerDrawError(from: error) {
                throw drawError
            }
            throw graphicsError(for: error, stage: stage, operation: operation)
        }
    }

    private func submissionGeometry(
        for leaseID: WaylandGraphicsFrameLeaseID
    ) async throws -> SurfaceGeometry {
        do {
            let geometry = try await window.geometry
            try leaseState.requireSubmittable(leaseID: leaseID)
            return geometry
        } catch {
            throw graphicsError(for: error, stage: .frameGeometry)
        }
    }

    private func prepareManagedGPUInitialConfigureIfNeeded(
        leaseID: WaylandGraphicsFrameLeaseID
    ) async throws {
        guard shouldAttemptManagedGPU else { return }

        let operation = try leaseState.submissionOperation(leaseID: leaseID)
        guard operation == .show else { return }

        do {
            _ = try await window.prepareGraphicsPreviewPresentation(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds
            )
            try leaseState.requireSubmittable(leaseID: leaseID)
        } catch {
            throw graphicsError(for: error, stage: .frameGeometry)
        }
    }

    private func ensureWindowOpen() async throws {
        do {
            let windowIsClosed = try await window.isClosed
            try leaseState.requireNotClosed()
            guard !windowIsClosed else {
                throw WaylandGraphicsError.windowClosed
            }
        } catch {
            throw graphicsError(for: error, stage: .windowStateCheck)
        }
    }

    private func graphicsError(
        for error: any Error,
        stage: WaylandGraphicsSubmissionStage,
        operation: WaylandGraphicsFrameSubmissionOperation? = nil
    ) -> WaylandGraphicsError {
        if leaseState.isClosed {
            return .backingClosed
        }
        if let graphicsError = error as? WaylandGraphicsError {
            return graphicsError
        }
        return WaylandGraphicsErrorMapper.mapSubmissionError(
            error,
            windowID: window.id,
            operation: operation?.graphicsSubmissionOperation,
            stage: stage
        )
    }

    func cancel(leaseID: WaylandGraphicsFrameLeaseID) {
        leaseState.cancel(leaseID: leaseID)
    }

    func close() async throws {
        guard !leaseState.isClosed else {
            return
        }

        leaseState.close()
        managedGPUBacking?.close()
        await window.close()
    }

    private func submitFrame(
        _ frame: WaylandGraphicsSubmittedFrame,
        operation: WaylandGraphicsFrameSubmissionOperation,
        geometry: SurfaceGeometry
    ) async throws {
        switch frame {
        case .clearColor(let clearFrame):
            try await submitClearFrame(
                clearFrame,
                operation: operation,
                geometry: geometry
            )
        }
    }

    private func submitClearFrame(
        _ frame: WaylandGraphicsClearFrame,
        operation: WaylandGraphicsFrameSubmissionOperation,
        geometry: SurfaceGeometry
    ) async throws {
        let color = frame.color.xrgb8888
        let metadata = try frame.metadata.surfaceCommitMetadata()
        let damage = try frame.metadata.surfaceDamageRegion()
        if shouldAttemptManagedGPU {
            do {
                _ = try await managedGPUBacking?.submitClearFrame(
                    WaylandGraphicsManagedGPUClearFrameSubmission(
                        color: frame.color.gpuClearColor,
                        metadata: metadata,
                        geometry: geometry,
                        synchronization: configuration.gpuSynchronization,
                        pacing: configuration.gpuPacing,
                        requestPresentationFeedback: shouldRequestPresentationFeedback
                    )
                )
                refreshRuntimePathFromManagedGPU(backing: .active)
                return
            } catch {
                try handleManagedGPUFailure(error)
            }
        }

        switch operation {
        case .show:
            try await window.show(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback,
                damage: damage
            ) { softwareFrame in
                Self.clear(softwareFrame, color: color)
            }
        case .redraw:
            try await window.redraw(
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback,
                damage: damage
            ) { softwareFrame in
                Self.clear(softwareFrame, color: color)
            }
        }
    }

    private func submitSoftwareFrame(
        metadata frameMetadata: WaylandGraphicsFrameMetadata,
        operation: WaylandGraphicsFrameSubmissionOperation,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        let metadata = try frameMetadata.surfaceCommitMetadata()
        let damage = try frameMetadata.surfaceDamageRegion()
        switch operation {
        case .show:
            try await window.show(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback,
                damage: damage,
                draw
            )
        case .redraw:
            try await window.redraw(
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback,
                damage: damage,
                draw
            )
        }
    }

    nonisolated private static func clear(
        _ frame: borrowing SoftwareFrame,
        color: UInt32
    ) {
        frame.withXRGB8888Rows { _, pixels in
            for index in 0..<pixels.count {
                unsafe pixels[unchecked: index] = color
            }
        }
    }
}

extension WaylandGraphicsWindowBackingStorage {
    package static func shouldRequestPresentationFeedback(
        configuration: WaylandGraphicsConfiguration,
        capabilities: WaylandGraphicsSurfaceCapabilities
    ) -> Bool {
        switch configuration.presentationFeedbackPolicy {
        case .none:
            false
        case .requestWhenAvailable, .require:
            capabilities.presentationFeedback.isAvailable
        }
    }

    private var shouldRequestPresentationFeedback: Bool {
        Self.shouldRequestPresentationFeedback(
            configuration: configuration,
            capabilities: backingRuntimePath.capabilities
        )
    }

    private var shouldAttemptManagedGPU: Bool {
        guard managedGPUBacking != nil else {
            return false
        }
        guard configuration.backingPreference == .managedGPU,
            configuration.fallbackPolicy != .forceSoftware
        else {
            return false
        }
        guard case .fallback = backingRuntimePath.backing else {
            return true
        }

        return false
    }

    private func handleManagedGPUFailure(
        _ error: ManagedGPUPreviewBackingError
    ) throws {
        switch configuration.fallbackPolicy {
        case .preferGPUFallbackToSoftware:
            let reason = WaylandGraphicsFallbackReason(error.fallbackReason)
            if !refreshRuntimePathFromManagedGPU(backing: .fallback(reason)) {
                backingRuntimePath = .softwareFallback(
                    capabilities: backingRuntimePath.capabilities,
                    reason: reason
                )
            }
        case .requireGPU:
            let reason = WaylandGraphicsUnavailableReason(error.failure)
            if !refreshRuntimePathFromManagedGPU(backing: .failed(reason)) {
                backingRuntimePath = .unavailable(
                    capabilities: backingRuntimePath.capabilities,
                    reason: reason
                )
            }
            throw WaylandGraphicsError.unavailable(reason)
        case .forceSoftware:
            backingRuntimePath = .softwareFallback(
                capabilities: backingRuntimePath.capabilities,
                reason: .forcedSoftware
            )
        }
    }

    @discardableResult
    private func refreshRuntimePathFromManagedGPU(
        backing: WaylandGraphicsRuntimeStatus
    ) -> Bool {
        guard let managedGPUBacking,
            let capabilities = managedGPUBacking.surfaceCapabilities
        else {
            return false
        }

        backingRuntimePath = WaylandGraphicsRuntimePath(
            gpuSnapshot: managedGPUBacking.runtimePathSnapshot,
            capabilities: capabilities,
            backing: backing
        )
        return true
    }

    private func frameResult(
        operation: WaylandGraphicsFrameSubmissionOperation,
        size: PositivePixelSize,
        metadata: WaylandGraphicsFrameMetadata
    ) -> WaylandGraphicsFrameResult {
        WaylandGraphicsFrameResult(
            runtimePath: backingRuntimePath,
            operation: operation.graphicsSubmissionOperation,
            size: size,
            metadata: metadata,
            presentationFeedbackRequested: shouldRequestPresentationFeedback,
            synchronizationPolicy: configuration.synchronizationPolicy,
            pacingPolicy: configuration.pacingPolicy
        )
    }
}
