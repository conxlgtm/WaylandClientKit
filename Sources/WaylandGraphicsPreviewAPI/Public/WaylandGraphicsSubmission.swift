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

public enum WaylandGraphicsError: Error, Equatable, Sendable {
    case unavailable(WaylandGraphicsUnavailableReason)
    case fallbackRequired(WaylandGraphicsFallbackReason)
    case windowClosed
    case backingClosed
    case frameLeaseActive
    case frameLeaseConsumed
    case unsupportedMetadata
    case internalFailure(String)
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

    public func cancel() async {
        await storage.cancel(leaseID: id)
    }
}

actor WaylandGraphicsWindowBackingStorage {
    let window: Window
    private let configuration: WaylandGraphicsConfiguration
    private var backingRuntimePath: WaylandGraphicsRuntimePath
    private var isClosed = false
    private var hasSubmittedFrame = false
    private var activeLeaseID: UInt64?
    private var nextLeaseID: UInt64 = 1

    init(
        window backingWindow: Window,
        runtimePath initialRuntimePath: WaylandGraphicsRuntimePath,
        configuration graphicsConfiguration: WaylandGraphicsConfiguration
    ) {
        window = backingWindow
        backingRuntimePath = initialRuntimePath
        configuration = graphicsConfiguration
    }

    func runtimePath() throws -> WaylandGraphicsRuntimePath {
        guard !isClosed else {
            throw WaylandGraphicsError.backingClosed
        }

        return backingRuntimePath
    }

    func nextFrame() async throws -> WaylandGraphicsFrameLease {
        guard !isClosed else {
            throw WaylandGraphicsError.backingClosed
        }
        guard activeLeaseID == nil else {
            throw WaylandGraphicsError.frameLeaseActive
        }
        guard try await !window.isClosed else {
            throw WaylandGraphicsError.windowClosed
        }

        let geometry = try await window.geometry
        let leaseID = nextLeaseID
        nextLeaseID += 1
        activeLeaseID = leaseID
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
        try consumeLease(leaseID)
        guard !isClosed else {
            throw WaylandGraphicsError.backingClosed
        }

        do {
            try await submitFrame(frame)
        } catch let graphicsError as WaylandGraphicsError {
            throw graphicsError
        } catch {
            throw WaylandGraphicsError.internalFailure(String(describing: error))
        }
    }

    func cancel(leaseID: UInt64) {
        guard activeLeaseID == leaseID else {
            return
        }

        activeLeaseID = nil
    }

    func close() async throws {
        guard !isClosed else {
            return
        }

        isClosed = true
        activeLeaseID = nil
        await window.close()
    }

    private func consumeLease(_ leaseID: UInt64) throws {
        guard activeLeaseID == leaseID else {
            throw WaylandGraphicsError.frameLeaseConsumed
        }

        activeLeaseID = nil
    }

    private func submitFrame(_ frame: WaylandGraphicsSubmittedFrame) async throws {
        switch frame {
        case .clearColor(let clearFrame):
            guard clearFrame.metadata == .default, configuration.metadataPolicy == .none
            else {
                throw WaylandGraphicsError.unsupportedMetadata
            }

            try await submitClearFrame(clearFrame)
        }
    }

    private func submitClearFrame(_ frame: WaylandGraphicsClearFrame) async throws {
        let color = frame.color.xrgb8888
        if hasSubmittedFrame {
            try await window.redraw { softwareFrame in
                Self.clear(softwareFrame, color: color)
            }
        } else {
            try await window.show { softwareFrame in
                Self.clear(softwareFrame, color: color)
            }
            hasSubmittedFrame = true
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
