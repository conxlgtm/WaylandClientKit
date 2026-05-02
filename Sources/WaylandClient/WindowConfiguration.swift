public enum CloseRequestPolicy: Equatable, Sendable {
    case requestOnly
    case autoClose
}

public struct WindowConfiguration: Equatable, Sendable {
    public var title: WaylandString
    public var appID: NonEmptyWaylandString
    public var initialSize: PositiveTopLevelSize
    public var bufferCount: PositiveInt
    public var closeRequestPolicy: CloseRequestPolicy

    public static let `default` = WindowConfiguration(
        title: WaylandString(unchecked: "SwiftWayland Demo"),
        appID: NonEmptyWaylandString(unchecked: "swift-wayland-demo"),
        initialSize: .default,
        bufferCount: PositiveInt(unchecked: 3),
        closeRequestPolicy: .requestOnly
    )

    public init(
        title windowTitle: WaylandString,
        appID applicationID: NonEmptyWaylandString,
        initialSize size: PositiveTopLevelSize,
        bufferCount count: PositiveInt,
        closeRequestPolicy policy: CloseRequestPolicy = .requestOnly
    ) {
        title = windowTitle
        appID = applicationID
        initialSize = size
        bufferCount = count
        closeRequestPolicy = policy
    }

    public init(
        title windowTitle: String = "SwiftWayland Demo",
        appID applicationID: String = "swift-wayland-demo",
        initialWidth width: Int32 = 640,
        initialHeight height: Int32 = 480,
        bufferCount count: Int = 3,
        closeRequestPolicy policy: CloseRequestPolicy = .requestOnly
    ) throws {
        guard width > 0 else {
            throw ClientError.invalidWindowConfiguration(.nonPositiveInitialWidth(width))
        }

        guard height > 0 else {
            throw ClientError.invalidWindowConfiguration(.nonPositiveInitialHeight(height))
        }

        guard count > 0 else {
            throw ClientError.invalidWindowConfiguration(.nonPositiveBufferCount(count))
        }

        guard !windowTitle.contains("\0") else {
            throw ClientError.invalidWindowConfiguration(.interiorNUL(field: "title"))
        }

        guard !applicationID.isEmpty else {
            throw ClientError.invalidWindowConfiguration(.emptyString(field: "appID"))
        }

        guard !applicationID.contains("\0") else {
            throw ClientError.invalidWindowConfiguration(.interiorNUL(field: "appID"))
        }

        title = WaylandString(unchecked: windowTitle)
        appID = NonEmptyWaylandString(unchecked: applicationID)
        initialSize = PositiveTopLevelSize(
            width: PositiveInt32(unchecked: width),
            height: PositiveInt32(unchecked: height)
        )
        bufferCount = PositiveInt(unchecked: count)
        closeRequestPolicy = policy
    }
}
