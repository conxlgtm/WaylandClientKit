public enum ClientError: Error, Equatable, Sendable, CustomStringConvertible {
    case windowCreationFailed(String)
    case invalidWindowState(String)
    case invalidDisplayState(String)
    case invalidWindowConfiguration(WindowConfigurationError)
    case invalidCursorConfiguration(String)
    case pointerCursorRequestFailed(String)
    case unknownWindow(WindowID)
    case displayClosed
    case window(WindowID, WindowError)

    public var description: String {
        switch self {
        case .windowCreationFailed(let detail):
            "Window creation failed: \(detail)"
        case .invalidWindowState(let detail):
            "Invalid window state: \(detail)"
        case .invalidDisplayState(let detail):
            "Invalid display state: \(detail)"
        case .invalidWindowConfiguration(let error):
            "Invalid window configuration: \(error.description)"
        case .invalidCursorConfiguration(let detail):
            "Invalid cursor configuration: \(detail)"
        case .pointerCursorRequestFailed(let detail):
            "Pointer cursor request failed: \(detail)"
        case .unknownWindow(let windowID):
            "Unknown window: \(windowID)"
        case .displayClosed:
            "Display is closed"
        case .window(let windowID, let error):
            "Window \(windowID) failed: \(error.description)"
        }
    }
}
