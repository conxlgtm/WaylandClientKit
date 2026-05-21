import WaylandClient

public struct WaylandGraphicsConfiguration: Equatable, Sendable {
    public var fallbackPolicy: WaylandGraphicsFallbackPolicy
    public var synchronizationPolicy: WaylandGraphicsSynchronizationPolicy
    public var pacingPolicy: WaylandGraphicsPacingPolicy
    public var metadataPolicy: WaylandGraphicsMetadataPolicy
    public var presentationFeedbackPolicy: WaylandGraphicsPresentationFeedbackPolicy

    public static let `default` = WaylandGraphicsConfiguration()

    public init(
        fallbackPolicy backingFallbackPolicy: WaylandGraphicsFallbackPolicy =
            .preferGPUFallbackToSoftware,
        synchronizationPolicy frameSynchronizationPolicy:
            WaylandGraphicsSynchronizationPolicy = .implicitOnly,
        pacingPolicy framePacingPolicy: WaylandGraphicsPacingPolicy = .none,
        metadataPolicy frameMetadataPolicy: WaylandGraphicsMetadataPolicy = .none,
        presentationFeedbackPolicy framePresentationFeedbackPolicy:
            WaylandGraphicsPresentationFeedbackPolicy = .none
    ) {
        fallbackPolicy = backingFallbackPolicy
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
                    .presentationFeedbackRequiredButUnavailable
                )
            }
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

public struct WaylandGraphicsFrameResult: Equatable, Sendable {
    public let runtimePath: WaylandGraphicsRuntimePath
    public let operation: WaylandGraphicsSubmissionOperation
    public let size: PositivePixelSize

    public init(
        runtimePath frameRuntimePath: WaylandGraphicsRuntimePath,
        operation frameOperation: WaylandGraphicsSubmissionOperation,
        size frameSize: PositivePixelSize
    ) {
        runtimePath = frameRuntimePath
        operation = frameOperation
        size = frameSize
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
    case unsupportedDamage
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
            try await window.show(metadata: metadata) { softwareFrame in
                Self.clear(softwareFrame, color: color)
            }
            try await requestPresentationFeedbackAfterInitialShowIfNeeded()
        case .redraw:
            try await requestPresentationFeedbackBeforeRedrawIfNeeded()
            try await window.redraw(metadata: metadata) { softwareFrame in
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
            try await window.show(metadata: metadata, draw)
            try await requestPresentationFeedbackAfterInitialShowIfNeeded()
        case .redraw:
            try await requestPresentationFeedbackBeforeRedrawIfNeeded()
            try await window.redraw(metadata: metadata, draw)
        }
    }

    private func requestPresentationFeedbackBeforeRedrawIfNeeded() async throws {
        guard shouldRequestPresentationFeedback else { return }
        try await window.requestPresentationFeedback()
    }

    private func requestPresentationFeedbackAfterInitialShowIfNeeded() async throws {
        guard shouldRequestPresentationFeedback else { return }
        try await window.requestPresentationFeedback()
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

extension WaylandGraphicsSubmittedFrame {
    package func validateManagedPreviewSupport(
        capabilities: WaylandGraphicsSurfaceCapabilities,
        geometry: SurfaceGeometry
    ) throws {
        switch self {
        case .clearColor(let clearFrame):
            try clearFrame.metadata.validateManagedPreviewSupport(
                capabilities: capabilities,
                geometry: geometry
            )
        }
    }
}

extension WaylandGraphicsFrameMetadata {
    package func validateManagedPreviewSupport(
        capabilities: WaylandGraphicsSurfaceCapabilities,
        geometry: SurfaceGeometry
    ) throws {
        try damage?.validateManagedPreviewSupport(geometry: geometry)
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
}

extension WaylandGraphicsDamageRegion {
    package func validateManagedPreviewSupport(geometry: SurfaceGeometry) throws {
        guard !rects.isEmpty else {
            return
        }

        let width = Int64(geometry.logicalSize.width.rawValue)
        let height = Int64(geometry.logicalSize.height.rawValue)
        for rect in rects {
            let x = Int64(rect.origin.x)
            let y = Int64(rect.origin.y)
            let rectWidth = Int64(rect.size.width.rawValue)
            let rectHeight = Int64(rect.size.height.rawValue)
            guard x >= 0, y >= 0, x + rectWidth <= width, y + rectHeight <= height else {
                throw WaylandGraphicsError.invalidDamageRegion
            }
        }

        throw WaylandGraphicsError.unsupportedDamage
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

private func noGraphicsPreviewSubmissionHook() async {
    _ = ()
}

private func noThrowingGraphicsPreviewSubmissionHook() async throws {
    _ = ()
}
