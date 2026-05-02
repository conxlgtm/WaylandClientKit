public enum ClientError: Error, Equatable, Sendable, CustomStringConvertible {
    case windowCreationFailed(String)
    case invalidWindowState(String)
    case display(DisplayOperationError)
    case invalidWindowConfiguration(WindowConfigurationError)
    case cursor(PointerCursorError)
    case window(WindowID, WindowError)

    public var description: String {
        switch self {
        case .windowCreationFailed(let detail):
            "Window creation failed: \(detail)"
        case .invalidWindowState(let detail):
            "Invalid window state: \(detail)"
        case .display(let error):
            "Display failed: \(error.description)"
        case .invalidWindowConfiguration(let error):
            "Invalid window configuration: \(error.description)"
        case .cursor(let error):
            "Cursor failed: \(error.description)"
        case .window(let windowID, let error):
            "Window \(windowID) failed: \(error.description)"
        }
    }
}
