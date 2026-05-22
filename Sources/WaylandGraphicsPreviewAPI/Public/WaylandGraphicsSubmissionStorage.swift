import WaylandClient

actor WaylandGraphicsWindowBackingStorage {
    let window: Window
    private let configuration: WaylandGraphicsConfiguration
    private var backingRuntimePath: WaylandGraphicsRuntimePath
    private var leaseState = WaylandGraphicsFrameLeaseState()

    init(
        window backingWindow: Window,
        runtimePath initialRuntimePath: WaylandGraphicsRuntimePath,
        configuration backingConfiguration: WaylandGraphicsConfiguration = .default
    ) {
        window = backingWindow
        configuration = backingConfiguration
        backingRuntimePath = initialRuntimePath
    }

    func runtimePath() throws -> WaylandGraphicsRuntimePath {
        try leaseState.requireNotClosed()
        return backingRuntimePath
    }

    func nextFrame() async throws -> WaylandGraphicsFrameLease {
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
        leaseID: UInt64,
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
        leaseID: UInt64,
        frame: WaylandGraphicsSubmittedFrame,
        beforeSubmissionEffect: @Sendable () async throws -> Void,
        afterSubmissionEffect: @Sendable () async throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()

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
            try await submitFrame(frame, operation: operation)
            stage = .submissionCompletion
            try await afterSubmissionEffect()
            try leaseState.finishSubmission()
            return frameResult(operation: operation, size: geometry.bufferSize)
        } catch {
            leaseState.failSubmission()
            throw graphicsError(for: error, stage: stage, operation: operation)
        }
    }

    func submitSoftware(
        leaseID: UInt64,
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
            return frameResult(operation: operation, size: geometry.bufferSize)
        } catch {
            leaseState.failSubmission()
            if let drawError = WaylandGraphicsErrorMapper.callerDrawError(from: error) {
                throw drawError
            }
            throw graphicsError(for: error, stage: stage, operation: operation)
        }
    }

    private func submissionGeometry(for leaseID: UInt64) async throws -> SurfaceGeometry {
        do {
            let geometry = try await window.geometry
            try leaseState.requireSubmittable(leaseID: leaseID)
            return geometry
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

    func cancel(leaseID: UInt64) {
        leaseState.cancel(leaseID: leaseID)
    }

    func close() async throws {
        guard !leaseState.isClosed else {
            return
        }

        leaseState.close()
        await window.close()
    }

    private func submitFrame(
        _ frame: WaylandGraphicsSubmittedFrame,
        operation: WaylandGraphicsFrameSubmissionOperation
    ) async throws {
        switch frame {
        case .clearColor(let clearFrame):
            try await submitClearFrame(clearFrame, operation: operation)
        }
    }

    private func submitClearFrame(
        _ frame: WaylandGraphicsClearFrame,
        operation: WaylandGraphicsFrameSubmissionOperation
    ) async throws {
        let color = frame.color.xrgb8888
        let metadata = try frame.metadata.surfaceCommitMetadata()
        switch operation {
        case .show:
            try await window.show(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback
            ) { softwareFrame in
                Self.clear(softwareFrame, color: color)
            }
        case .redraw:
            try await window.redraw(
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback
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
        switch operation {
        case .show:
            try await window.show(
                timeoutMilliseconds: WaylandDisplay.defaultConfigureTimeoutMilliseconds,
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback,
                draw
            )
        case .redraw:
            try await window.redraw(
                metadata: metadata,
                requestPresentationFeedback: shouldRequestPresentationFeedback,
                draw
            )
        }
    }

    private var shouldRequestPresentationFeedback: Bool {
        switch configuration.presentationFeedbackPolicy {
        case .none:
            false
        case .requestWhenAvailable, .require:
            backingRuntimePath.capabilities.presentationFeedback.isAvailable
        }
    }

    private func frameResult(
        operation: WaylandGraphicsFrameSubmissionOperation,
        size: PositivePixelSize
    ) -> WaylandGraphicsFrameResult {
        WaylandGraphicsFrameResult(
            runtimePath: backingRuntimePath,
            operation: operation.graphicsSubmissionOperation,
            size: size
        )
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
