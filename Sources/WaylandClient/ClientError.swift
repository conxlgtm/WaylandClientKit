public enum ClientError: Error, CustomStringConvertible {
    case windowCreationFailed(String)
    case invalidWindowState(String)

    public var description: String {
        switch self {
        case .windowCreationFailed(let detail):
            "Window creation failed: \(detail)"
        case .invalidWindowState(let detail):
            "Invalid window state: \(detail)"
        }
    }
}
