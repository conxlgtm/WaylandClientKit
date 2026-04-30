public enum CloseRequestPolicy: Equatable, Sendable {
    case requestOnly
    case autoClose
}

public struct WindowConfiguration: Sendable {
    public var title: String
    public var appID: String
    public var initialWidth: Int32
    public var initialHeight: Int32
    public var bufferCount: Int
    public var closeRequestPolicy: CloseRequestPolicy

    public init(
        title windowTitle: String = "SwiftWayland Demo",
        appID applicationID: String = "swift-wayland-demo",
        initialWidth width: Int32 = 640,
        initialHeight height: Int32 = 480,
        bufferCount count: Int = 3,
        closeRequestPolicy policy: CloseRequestPolicy = .requestOnly
    ) {
        title = windowTitle
        appID = applicationID
        initialWidth = width
        initialHeight = height
        bufferCount = count
        closeRequestPolicy = policy
    }

    package func validate() throws {
        guard initialWidth > 0 else {
            throw ClientError.invalidWindowConfiguration("initialWidth must be greater than zero")
        }

        guard initialHeight > 0 else {
            throw ClientError.invalidWindowConfiguration("initialHeight must be greater than zero")
        }

        guard bufferCount > 0 else {
            throw ClientError.invalidWindowConfiguration("bufferCount must be greater than zero")
        }

        try CStringValidation.requireNoInteriorNUL(title, fieldName: "title")
        try CStringValidation.requireNonEmptyNoInteriorNUL(
            appID,
            fieldName: "appID",
            error: ClientError.invalidWindowConfiguration
        )
    }
}
