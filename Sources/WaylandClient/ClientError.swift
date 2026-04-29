public enum ClientError: Error, Sendable, CustomStringConvertible {
    case windowCreationFailed(String)
    case invalidWindowState(String)
    case invalidCursorConfiguration(String)

    public var description: String {
        switch self {
        case .windowCreationFailed(let detail):
            "Window creation failed: \(detail)"
        case .invalidWindowState(let detail):
            "Invalid window state: \(detail)"
        case .invalidCursorConfiguration(let detail):
            "Invalid cursor configuration: \(detail)"
        }
    }
}
