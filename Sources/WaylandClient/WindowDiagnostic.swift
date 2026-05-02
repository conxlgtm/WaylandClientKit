public enum WindowCallbackOperation: Equatable, Sendable, CustomStringConvertible {
    case closeRequested
    case transientStateReset
    case frameDone
    case bufferReleased
    case markNeedsRedraw
    case close

    public var description: String {
        switch self {
        case .closeRequested:
            "closeRequested"
        case .transientStateReset:
            "transientStateReset"
        case .frameDone:
            "frameDone"
        case .bufferReleased:
            "bufferReleased"
        case .markNeedsRedraw:
            "markNeedsRedraw"
        case .close:
            "close"
        }
    }
}

public enum WindowLifecycleOperation: Equatable, Sendable, CustomStringConvertible {
    case close

    public var description: String {
        switch self {
        case .close:
            "close"
        }
    }
}

public enum WindowPresentationOperation: Equatable, Sendable, CustomStringConvertible {
    case presentationFailed

    public var description: String {
        switch self {
        case .presentationFailed:
            "presentationFailed"
        }
    }
}

public enum WindowDiagnosticOperation: Equatable, Sendable {
    case callback(WindowCallbackOperation)
    case lifecycle(WindowLifecycleOperation)
    case presentation(WindowPresentationOperation)
}

public struct WindowDiagnostic: Equatable, Sendable {
    public let windowID: WindowID
    public let operation: WindowDiagnosticOperation
    public let message: String

    public init(
        windowID diagnosticWindowID: WindowID,
        operation diagnosticOperation: WindowDiagnosticOperation,
        message diagnosticMessage: String
    ) {
        windowID = diagnosticWindowID
        operation = diagnosticOperation
        message = diagnosticMessage
    }
}
