import WaylandRaw

public struct WindowConfiguration: Sendable {
    public var title: String
    public var appID: String
    public var initialWidth: Int32
    public var initialHeight: Int32
    public var bufferCount: Int

    public init(
        title windowTitle: String = "Wayforge Demo",
        appID applicationID: String = "wayforge-demo",
        initialWidth width: Int32 = 640,
        initialHeight height: Int32 = 480,
        bufferCount count: Int = 3
    ) {
        title = windowTitle
        appID = applicationID
        initialWidth = width
        initialHeight = height
        bufferCount = count
    }

    var fallbackSize: TopLevelSize {
        .init(width: initialWidth, height: initialHeight)
            .normalized()
    }
}
