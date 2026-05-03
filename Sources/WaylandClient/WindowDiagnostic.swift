public enum WindowCallbackOperation: Equatable, Sendable, CustomStringConvertible {
    case closeRequested
    case transientStateReset
    case frameDone
    case bufferReleased
    case markNeedsRedraw
    case surfaceScaleChanged
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
        case .surfaceScaleChanged:
            "surfaceScaleChanged"
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

public enum WindowDecorationOperation: Equatable, Sendable, CustomStringConvertible {
    case decorationUnavailable

    public var description: String {
        switch self {
        case .decorationUnavailable:
            "decorationUnavailable"
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

public enum WindowScaleOperation: Equatable, Sendable, CustomStringConvertible {
    case fractionalScaleUnavailable

    public var description: String {
        switch self {
        case .fractionalScaleUnavailable:
            "fractionalScaleUnavailable"
        }
    }
}

public enum WindowDiagnosticOperation: Equatable, Sendable {
    case callback(WindowCallbackOperation)
    case lifecycle(WindowLifecycleOperation)
    case decoration(WindowDecorationOperation)
    case presentation(WindowPresentationOperation)
    case scale(WindowScaleOperation)
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
