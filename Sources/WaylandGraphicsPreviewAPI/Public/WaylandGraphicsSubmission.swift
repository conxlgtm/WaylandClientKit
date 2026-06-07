import WaylandClient
import WaylandGPUPreview

// swiftlint:disable file_length

public struct WaylandGraphicsConfiguration: Equatable, Sendable {
    public var fallbackPolicy: WaylandGraphicsFallbackPolicy
    public var backingPreference: WaylandGraphicsBackingKind
    public var synchronizationPolicy: WaylandGraphicsSynchronizationPolicy
    public var pacingPolicy: WaylandGraphicsPacingPolicy
    public var metadataPolicy: WaylandGraphicsMetadataPolicy
    public var presentationFeedbackPolicy: WaylandGraphicsPresentationFeedbackPolicy

    public static let `default` = WaylandGraphicsConfiguration()

    public init(
        fallbackPolicy backingFallbackPolicy: WaylandGraphicsFallbackPolicy =
            .preferGPUFallbackToSoftware,
        backingPreference preferredBacking: WaylandGraphicsBackingKind = .managedGPU,
        synchronizationPolicy frameSynchronizationPolicy:
            WaylandGraphicsSynchronizationPolicy = .implicitOnly,
        pacingPolicy framePacingPolicy: WaylandGraphicsPacingPolicy = .none,
        metadataPolicy frameMetadataPolicy: WaylandGraphicsMetadataPolicy = .none,
        presentationFeedbackPolicy framePresentationFeedbackPolicy:
            WaylandGraphicsPresentationFeedbackPolicy = .none
    ) {
        fallbackPolicy = backingFallbackPolicy
        backingPreference = preferredBacking
        synchronizationPolicy = frameSynchronizationPolicy
        pacingPolicy = framePacingPolicy
        metadataPolicy = frameMetadataPolicy
        presentationFeedbackPolicy = framePresentationFeedbackPolicy
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

        switch presentationFeedbackPolicy {
        case .none, .requestWhenAvailable:
            break
        case .require:
            guard capabilities.presentationFeedback.isAvailable else {
                throw WaylandGraphicsError.unavailable(
                    .presentationFeedbackUnavailable
                )
            }
        }
    }

    package var gpuSynchronization: GPUBufferSubmissionSynchronization {
        switch synchronizationPolicy {
        case .implicitOnly, .preferExplicit, .requireExplicit:
            .implicit
        }
    }

    package var gpuPacing: SurfacePacingConstraint {
        switch pacingPolicy {
        case .none, .preferFIFO, .preferCommitTiming:
            .none
        }
    }
}

public enum WaylandGraphicsBackingKind: Equatable, Sendable {
    case software
    case managedGPU
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

public enum WaylandGraphicsPresentationFeedbackPolicy: Equatable, Sendable {
    case none
    case requestWhenAvailable
    case require
}

public struct WaylandGraphicsDamageRegion: Equatable, Sendable {
    public let rects: [LogicalRect]

    public static let fullFrame = WaylandGraphicsDamageRegion(rects: [])

    public init(rects damageRects: [LogicalRect]) {
        rects = damageRects
    }
}

public struct WaylandGraphicsFrameMetadata: Equatable, Sendable {
    public var contentType: WaylandGraphicsContentType?
    public var presentationHint: WaylandGraphicsPresentationHint?
    public var damage: WaylandGraphicsDamageRegion?

    public static let `default` = WaylandGraphicsFrameMetadata()

    public init(
        contentType frameContentType: WaylandGraphicsContentType? = nil,
        presentationHint framePresentationHint: WaylandGraphicsPresentationHint? = nil,
        damage frameDamage: WaylandGraphicsDamageRegion? = nil
    ) {
        contentType = frameContentType
        presentationHint = framePresentationHint
        damage = frameDamage
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

    package var gpuClearColor: GPUClearColor {
        GPUClearColor(
            red: Float(red) / 255,
            green: Float(green) / 255,
            blue: Float(blue) / 255,
            alpha: 1
        )
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

    package var metadata: WaylandGraphicsFrameMetadata {
        switch self {
        case .clearColor(let clearFrame):
            clearFrame.metadata
        }
    }
}

public enum WaylandGraphicsSubmissionOperation: Equatable, Sendable {
    case show
    case redraw
}

public struct WaylandGraphicsFrameResult: Equatable, Sendable {
    public let runtimePath: WaylandGraphicsRuntimePath
    public let operation: WaylandGraphicsSubmissionOperation
    public let size: PositivePixelSize
    public let metadata: WaylandGraphicsFrameMetadata
    public let presentationFeedbackRequested: Bool
    public let synchronizationPolicy: WaylandGraphicsSynchronizationPolicy
    public let pacingPolicy: WaylandGraphicsPacingPolicy
    public var backing: WaylandGraphicsRuntimeStatus {
        runtimePath.backing
    }

    public init(
        runtimePath frameRuntimePath: WaylandGraphicsRuntimePath,
        operation frameOperation: WaylandGraphicsSubmissionOperation,
        size frameSize: PositivePixelSize,
        metadata frameMetadata: WaylandGraphicsFrameMetadata = .default,
        presentationFeedbackRequested framePresentationFeedbackRequested: Bool = false,
        synchronizationPolicy frameSynchronizationPolicy:
            WaylandGraphicsSynchronizationPolicy = .implicitOnly,
        pacingPolicy framePacingPolicy: WaylandGraphicsPacingPolicy = .none
    ) {
        runtimePath = frameRuntimePath
        operation = frameOperation
        size = frameSize
        metadata = frameMetadata
        presentationFeedbackRequested = framePresentationFeedbackRequested
        synchronizationPolicy = frameSynchronizationPolicy
        pacingPolicy = framePacingPolicy
    }
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
    case invalidDamageRegion
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

    public var id: WindowID {
        window.id
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

extension WaylandGraphicsWindowBacking: Identifiable {}

public struct WaylandGraphicsFrameLease: Sendable {
    public let size: PositivePixelSize
    public let runtimePath: WaylandGraphicsRuntimePath

    private let storage: WaylandGraphicsWindowBackingStorage
    private let id: WaylandGraphicsFrameLeaseID

    init(
        id leaseID: WaylandGraphicsFrameLeaseID,
        size frameSize: PositivePixelSize,
        runtimePath frameRuntimePath: WaylandGraphicsRuntimePath,
        storage backingStorage: WaylandGraphicsWindowBackingStorage
    ) {
        id = leaseID
        size = frameSize
        runtimePath = frameRuntimePath
        storage = backingStorage
    }

    @discardableResult
    public func submit(_ frame: WaylandGraphicsSubmittedFrame) async throws
        -> WaylandGraphicsFrameResult
    {
        try await storage.submit(leaseID: id, frame: frame)
    }

    @discardableResult
    public func submitSoftware(
        metadata frameMetadata: WaylandGraphicsFrameMetadata = .default,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try await storage.submitSoftware(
            leaseID: id,
            metadata: frameMetadata,
            draw
        )
    }

    @discardableResult
    package func submitForTestingBeforeSubmissionEffect(
        _ frame: WaylandGraphicsSubmittedFrame,
        _ beforeSubmissionEffect: @Sendable @escaping () async throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
        try await storage.submit(
            leaseID: id,
            frame: frame,
            beforeSubmissionEffect: beforeSubmissionEffect,
            afterSubmissionEffect: noThrowingGraphicsPreviewSubmissionHook
        )
    }

    @discardableResult
    package func submitForTesting(
        _ frame: WaylandGraphicsSubmittedFrame,
        afterSubmissionEffect: @Sendable @escaping () async throws -> Void
    ) async throws -> WaylandGraphicsFrameResult {
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

extension WaylandGraphicsSubmittedFrame {
    package func validateManagedPreviewSupport(
        configuration: WaylandGraphicsConfiguration,
        capabilities: WaylandGraphicsSurfaceCapabilities,
        geometry: SurfaceGeometry
    ) throws {
        switch self {
        case .clearColor(let clearFrame):
            try clearFrame.metadata.validateManagedPreviewSupport(
                configuration: configuration,
                capabilities: capabilities,
                geometry: geometry
            )
        }
    }
}

extension WaylandGraphicsFrameMetadata {
    package func validateManagedPreviewSupport(
        configuration: WaylandGraphicsConfiguration,
        capabilities: WaylandGraphicsSurfaceCapabilities,
        geometry: SurfaceGeometry
    ) throws {
        try damage?.validateManagedPreviewSupport(geometry: geometry)
        if hasCommitMetadata, configuration.metadataPolicy == .none {
            throw WaylandGraphicsError.unsupportedMetadata
        }
        if contentType != nil, !capabilities.colorMetadata.contentType.isAvailable {
            throw WaylandGraphicsError.unavailable(.metadataRequiredButUnavailable)
        }
        if presentationHint != nil, !capabilities.colorMetadata.tearingControl.isAvailable {
            throw WaylandGraphicsError.unavailable(.metadataRequiredButUnavailable)
        }
    }

    package func surfaceCommitMetadata() throws -> SurfaceCommitMetadata {
        SurfaceCommitMetadata(
            contentType: contentType?.surfaceContentType,
            presentationHint: presentationHint?.surfacePresentationHint
        )
    }

    package func surfaceDamageRegion() throws -> SurfaceDamageRegion? {
        try damage?.surfaceDamageRegion()
    }

    private var hasCommitMetadata: Bool {
        contentType != nil || presentationHint != nil
    }
}

extension WaylandGraphicsDamageRegion {
    package func validateManagedPreviewSupport(geometry: SurfaceGeometry) throws {
        let region = try surfaceDamageRegion()
        do {
            try region?.validate(within: geometry)
        } catch {
            throw WaylandGraphicsError.invalidDamageRegion
        }
    }

    package func surfaceDamageRegion() throws -> SurfaceDamageRegion? {
        guard !rects.isEmpty else { return nil }

        do {
            return try SurfaceDamageRegion(rects)
        } catch {
            throw WaylandGraphicsError.invalidDamageRegion
        }
    }
}

extension WaylandGraphicsContentType {
    package var surfaceContentType: SurfaceContentType {
        switch self {
        case .none:
            .none
        case .photo:
            .photo
        case .video:
            .video
        case .game:
            .game
        }
    }
}

extension WaylandGraphicsPresentationHint {
    package var surfacePresentationHint: SurfacePresentationHint {
        switch self {
        case .vsync:
            .vsync
        case .async:
            .async
        }
    }
}

func noGraphicsPreviewSubmissionHook() async {
    _ = ()
}

func noThrowingGraphicsPreviewSubmissionHook() async throws {
    _ = ()
}
