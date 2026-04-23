public struct TopLevelSize: Equatable, Sendable {
    public let width: Int32
    public let height: Int32

    public static let fallback = TopLevelSize(width: 640, height: 480)

    public init(width sizeWidth: Int32, height sizeHeight: Int32) {
        width = sizeWidth
        height = sizeHeight
    }

    public func normalized(fallback: TopLevelSize = .fallback) -> Self {
        Self(
            width: width > 0 ? width : fallback.width,
            height: height > 0 ? height : fallback.height)
    }
}

public struct SurfaceConfigure: Equatable, Sendable {
    public let serial: UInt32
    public let size: TopLevelSize

    public init(serial configureSerial: UInt32, size configureSize: TopLevelSize) {
        serial = configureSerial
        size = configureSize
    }
}

public final class XDGConfigureState {
    private let fallbackSize: TopLevelSize
    private var pendingSize: TopLevelSize
    private var latestConfigure: SurfaceConfigure?

    public private(set) var hasReceivedInitialConfigure = false

    public init(fallbackSize initialFallbackSize: TopLevelSize = .fallback) {
        fallbackSize = initialFallbackSize
        pendingSize = initialFallbackSize
    }

    public func handleTopLevelConfigure(width: Int32, height: Int32) {
        pendingSize = TopLevelSize(width: width, height: height)
            .normalized(fallback: fallbackSize)
    }

    @discardableResult
    public func handleSurfaceConfigure(serial: UInt32) -> SurfaceConfigure {
        let configure = SurfaceConfigure(serial: serial, size: pendingSize)
        latestConfigure = configure
        hasReceivedInitialConfigure = true
        return configure
    }

    public func consumeLatestConfigure() -> SurfaceConfigure? {
        defer {
            latestConfigure = nil
        }

        return latestConfigure
    }
}
