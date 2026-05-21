import WaylandClient

public struct WaylandGraphicsConfiguration: Equatable, Sendable {
    public var fallbackPolicy: WaylandGraphicsFallbackPolicy
    public var synchronizationPolicy: WaylandGraphicsSynchronizationPolicy
    public var pacingPolicy: WaylandGraphicsPacingPolicy
    public var metadataPolicy: WaylandGraphicsMetadataPolicy

    public static let `default` = WaylandGraphicsConfiguration()

    public init(
        fallbackPolicy backingFallbackPolicy: WaylandGraphicsFallbackPolicy =
            .preferGPUFallbackToSoftware,
        synchronizationPolicy frameSynchronizationPolicy:
            WaylandGraphicsSynchronizationPolicy = .implicitOnly,
        pacingPolicy framePacingPolicy: WaylandGraphicsPacingPolicy = .none,
        metadataPolicy frameMetadataPolicy: WaylandGraphicsMetadataPolicy = .none
    ) {
        fallbackPolicy = backingFallbackPolicy
        synchronizationPolicy = frameSynchronizationPolicy
        pacingPolicy = framePacingPolicy
        metadataPolicy = frameMetadataPolicy
    }
}

extension WaylandGraphicsConfiguration {
    package func validateManagedPreviewSupport(
        capabilities: WaylandGraphicsSurfaceCapabilities
    ) throws {
        switch synchronizationPolicy {
        case .implicitOnly, .preferExplicit:
            break
        case .requireExplicit:
            guard capabilities.explicitSync.isAvailable else {
                throw WaylandGraphicsError.unavailable(
                    .explicitSyncRequiredButUnavailable
                )
            }
            throw WaylandGraphicsError.unavailable(
                .managedGPUSubmissionUnavailable
            )
        }

        switch pacingPolicy {
        case .none:
            break
        case .preferFIFO, .preferCommitTiming:
            throw WaylandGraphicsError.unsupportedPacing
        }
    }
}

public enum WaylandGraphicsSynchronizationPolicy: Equatable, Sendable {
    case implicitOnly
    case preferExplicit
    case requireExplicit
}

public enum WaylandGraphicsPacingPolicy: Equatable, Sendable {
    case none
    case preferFIFO
    case preferCommitTiming
}

public enum WaylandGraphicsMetadataPolicy: Equatable, Sendable {
    case none
    case preferAvailable
}

public struct WaylandGraphicsFrameMetadata: Equatable, Sendable {
    public var contentType: WaylandGraphicsContentType?
    public var presentationHint: WaylandGraphicsPresentationHint?

    public static let `default` = WaylandGraphicsFrameMetadata()

    public init(
        contentType frameContentType: WaylandGraphicsContentType? = nil,
        presentationHint framePresentationHint: WaylandGraphicsPresentationHint? = nil
    ) {
        contentType = frameContentType
        presentationHint = framePresentationHint
    }
}

public enum WaylandGraphicsContentType: Equatable, Sendable {
    case none
    case photo
    case video
    case game
}

public enum WaylandGraphicsPresentationHint: Equatable, Sendable {
    case vsync
    case async
}

public struct WaylandGraphicsXRGBColor: Equatable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public static let black = WaylandGraphicsXRGBColor(red: 0, green: 0, blue: 0)

    public init(red colorRed: UInt8, green colorGreen: UInt8, blue colorBlue: UInt8) {
        red = colorRed
        green = colorGreen
        blue = colorBlue
    }

    package var xrgb8888: UInt32 {
        (UInt32(red) << 16) | (UInt32(green) << 8) | UInt32(blue)
    }
}

public struct WaylandGraphicsClearFrame: Equatable, Sendable {
    public let color: WaylandGraphicsXRGBColor
    public let metadata: WaylandGraphicsFrameMetadata

    public init(
        color clearColor: WaylandGraphicsXRGBColor,
        metadata frameMetadata: WaylandGraphicsFrameMetadata = .default
    ) {
        color = clearColor
        metadata = frameMetadata
    }
}

public enum WaylandGraphicsSubmittedFrame: Equatable, Sendable {
    case clearColor(WaylandGraphicsClearFrame)

    public static func clearColor(_ color: WaylandGraphicsXRGBColor) -> Self {
        .clearColor(WaylandGraphicsClearFrame(color: color))
    }
}

public enum WaylandGraphicsSubmissionOperation: Equatable, Sendable {
    case show
    case redraw
}

public enum WaylandGraphicsSubmissionStage: Equatable, Sendable {
    case windowStateCheck
    case frameGeometry
    case submissionPreparation
    case frameSubmission
    case submissionCompletion
}

public enum WaylandGraphicsSubmissionFailure: Equatable, Sendable {
    case windowLifecycle(
        windowID: WindowID,
        transition: WindowLifecycleTransitionError,
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage
    )
    case window(
        windowID: WindowID,
        error: WindowError,
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage
    )
    case display(
        error: DisplayOperationError,
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage
    )
    case client(
        error: ClientError,
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage
    )
    case unexpected(
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage,
        description: String
    )
}

public enum WaylandGraphicsError: Error, Equatable, Sendable {
    case unavailable(WaylandGraphicsUnavailableReason)
    case fallbackRequired(WaylandGraphicsFallbackReason)
    case windowClosed
    case backingClosed
    case frameLeaseActive
    case frameLeaseConsumed
    case unsupportedMetadata
    case unsupportedPacing
    case submissionFailed(WaylandGraphicsSubmissionFailure)
}

public struct WaylandGraphicsWindowBacking: Sendable {
    public let window: Window
    private let storage: WaylandGraphicsWindowBackingStorage

    init(
        window backingWindow: Window,
        storage backingStorage: WaylandGraphicsWindowBackingStorage
    ) {
        window = backingWindow
        storage = backingStorage
    }

    public var runtimePath: WaylandGraphicsRuntimePath {
        get async throws {
            try await storage.runtimePath()
        }
    }

    public func nextFrame() async throws -> WaylandGraphicsFrameLease {
        try await storage.nextFrame()
    }

    package func nextFrameForTesting(
        afterWindowCheck: @Sendable @escaping () async -> Void
    ) async throws -> WaylandGraphicsFrameLease {
        try await storage.nextFrame(afterWindowCheck: afterWindowCheck)
    }

    public func close() async throws {
        try await storage.close()
    }
}

public struct WaylandGraphicsFrameLease: Sendable {
    public let size: PositivePixelSize
    public let runtimePath: WaylandGraphicsRuntimePath

    private let storage: WaylandGraphicsWindowBackingStorage
    private let id: UInt64

    init(
        id leaseID: UInt64,
        size frameSize: PositivePixelSize,
        runtimePath frameRuntimePath: WaylandGraphicsRuntimePath,
        storage backingStorage: WaylandGraphicsWindowBackingStorage
    ) {
        id = leaseID
        size = frameSize
        runtimePath = frameRuntimePath
        storage = backingStorage
    }

    public func submit(_ frame: WaylandGraphicsSubmittedFrame) async throws {
        try await storage.submit(leaseID: id, frame: frame)
    }

    package func submitForTestingBeforeSubmissionEffect(
        _ frame: WaylandGraphicsSubmittedFrame,
        _ beforeSubmissionEffect: @Sendable @escaping () async throws -> Void
    ) async throws {
        try await storage.submit(
            leaseID: id,
            frame: frame,
            beforeSubmissionEffect: beforeSubmissionEffect,
            afterSubmissionEffect: noThrowingGraphicsPreviewSubmissionHook
        )
    }

    package func submitForTesting(
        _ frame: WaylandGraphicsSubmittedFrame,
        afterSubmissionEffect: @Sendable @escaping () async throws -> Void
    ) async throws {
        try await storage.submit(
            leaseID: id,
            frame: frame,
            beforeSubmissionEffect: noThrowingGraphicsPreviewSubmissionHook,
            afterSubmissionEffect: afterSubmissionEffect
        )
    }

    public func cancel() async {
        await storage.cancel(leaseID: id)
    }
}

actor WaylandGraphicsWindowBackingStorage {
    let window: Window
    private var backingRuntimePath: WaylandGraphicsRuntimePath
    private var leaseState = WaylandGraphicsFrameLeaseState()

    init(
        window backingWindow: Window,
        runtimePath initialRuntimePath: WaylandGraphicsRuntimePath
    ) {
        window = backingWindow
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
    ) async throws {
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
    ) async throws {
        try leaseState.requireNotClosed()
        try await ensureWindowOpen()

        let operation = try leaseState.prepareSubmission(leaseID: leaseID, frame: frame)
        var stage = WaylandGraphicsSubmissionStage.submissionPreparation
        do {
            try await beforeSubmissionEffect()
            stage = .frameSubmission
            try await submitFrame(frame, operation: operation)
            stage = .submissionCompletion
            try await afterSubmissionEffect()
            try leaseState.finishSubmission()
        } catch {
            leaseState.failSubmission()
            throw graphicsError(for: error, stage: stage, operation: operation)
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
        switch operation {
        case .show:
            try await window.show { softwareFrame in
                Self.clear(softwareFrame, color: color)
            }
        case .redraw:
            try await window.redraw { softwareFrame in
                Self.clear(softwareFrame, color: color)
            }
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

private func noGraphicsPreviewSubmissionHook() async {
    _ = ()
}

private func noThrowingGraphicsPreviewSubmissionHook() async throws {
    _ = ()
}
