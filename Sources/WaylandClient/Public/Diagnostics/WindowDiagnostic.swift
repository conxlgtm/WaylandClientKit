import WaylandRaw

public enum WindowCallbackOperation: Equatable, Sendable, CustomStringConvertible {
    case closeRequested
    case transientStateReset
    case frameDone
    case bufferReleased
    case markNeedsRedraw
    case surfaceScaleChanged
    case presentationFeedback
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
        case .presentationFeedback:
            "presentationFeedback"
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

public enum UnknownWindowProtocolValueField: Equatable, Hashable, Sendable,
    CustomStringConvertible
{
    case xdgTopLevelState
    case xdgWMCapability
    case xdgDecorationMode

    public var description: String {
        switch self {
        case .xdgTopLevelState:
            "xdg_toplevel state"
        case .xdgWMCapability:
            "xdg_toplevel wm capability"
        case .xdgDecorationMode:
            "zxdg_toplevel_decoration_v1 mode"
        }
    }
}

public struct UnknownWindowProtocolValueDiagnostic: Equatable, Sendable,
    CustomStringConvertible
{
    public let field: UnknownWindowProtocolValueField
    public let rawValue: UInt32
    public let configureSerial: UInt32

    public init(
        field diagnosticField: UnknownWindowProtocolValueField,
        rawValue diagnosticRawValue: UInt32,
        configureSerial diagnosticConfigureSerial: UInt32
    ) {
        field = diagnosticField
        rawValue = diagnosticRawValue
        configureSerial = diagnosticConfigureSerial
    }

    public var description: String {
        "unknown \(field.description) \(rawValue) in configure serial \(configureSerial)"
    }
}

public enum WindowDiagnosticOperation: Equatable, Sendable {
    case callback(WindowCallbackOperation)
    case lifecycle(WindowLifecycleOperation)
    case decoration(WindowDecorationOperation)
    case presentation(WindowPresentationOperation)
    case scale(WindowScaleOperation)
    case unknownProtocolValue(UnknownWindowProtocolValueField)
}

public struct WindowDiagnostic: Equatable, Sendable {
    public let windowID: WindowID
    public let payload: WindowDiagnosticPayload

    public var operation: WindowDiagnosticOperation {
        payload.operation
    }

    public var message: String {
        payload.description
    }

    public init(
        windowID diagnosticWindowID: WindowID,
        payload diagnosticPayload: WindowDiagnosticPayload
    ) {
        windowID = diagnosticWindowID
        payload = diagnosticPayload
    }
}

public enum WindowDiagnosticPayload: Equatable, Sendable, CustomStringConvertible {
    case callback(WindowCallbackDiagnostic)
    case decoration(WindowDecorationDiagnostic)
    case presentation(WindowPresentationDiagnostic)
    case scale(WindowScaleDiagnostic)
    case unknownProtocolValue(UnknownWindowProtocolValueDiagnostic)

    public var operation: WindowDiagnosticOperation {
        switch self {
        case .callback(let diagnostic):
            .callback(diagnostic.operation)
        case .decoration(let diagnostic):
            .decoration(diagnostic.operation)
        case .presentation(let diagnostic):
            .presentation(diagnostic.operation)
        case .scale(let diagnostic):
            .scale(diagnostic.operation)
        case .unknownProtocolValue(let diagnostic):
            .unknownProtocolValue(diagnostic.field)
        }
    }

    public var description: String {
        switch self {
        case .callback(let diagnostic):
            diagnostic.description
        case .decoration(let diagnostic):
            diagnostic.description
        case .presentation(let diagnostic):
            diagnostic.description
        case .scale(let diagnostic):
            diagnostic.description
        case .unknownProtocolValue(let diagnostic):
            diagnostic.description
        }
    }
}

public struct WindowCallbackDiagnostic: Equatable, Sendable, CustomStringConvertible {
    public let operation: WindowCallbackOperation
    public let failure: WindowCallbackFailure

    public init(
        operation diagnosticOperation: WindowCallbackOperation,
        failure diagnosticFailure: WindowCallbackFailure
    ) {
        operation = diagnosticOperation
        failure = diagnosticFailure
    }

    public var description: String {
        "\(operation.description) callback failed: \(failure.description)"
    }
}

public enum WindowCallbackFailure: Equatable, Sendable, CustomStringConvertible {
    case displayClosed

    public var description: String {
        switch self {
        case .displayClosed:
            ClientError.display(.closed).description
        }
    }
}

public struct WindowDecorationDiagnostic: Equatable, Sendable, CustomStringConvertible {
    public let operation: WindowDecorationOperation
    public let reason: WindowDecorationUnavailableReason

    public init(
        operation diagnosticOperation: WindowDecorationOperation,
        reason diagnosticReason: WindowDecorationUnavailableReason
    ) {
        operation = diagnosticOperation
        reason = diagnosticReason
    }

    public var description: String {
        reason.description
    }
}

public enum WindowDecorationUnavailableReason: Equatable, Sendable, CustomStringConvertible {
    case managerMissing
    case unsupportedManagerVersion(advertised: UInt32, minimum: UInt32)

    package init(_ reason: DecorationUnavailableReason) {
        switch reason {
        case .managerMissing:
            self = .managerMissing
        case .unsupportedManagerVersion(let advertised, let minimum):
            self = .unsupportedManagerVersion(
                advertised: advertised.value,
                minimum: minimum.value
            )
        }
    }

    public var description: String {
        switch self {
        case .managerMissing:
            "Server-side decoration protocol is unavailable."
        case .unsupportedManagerVersion(let advertised, let minimum):
            "Server-side decoration protocol v\(advertised) is unsupported; "
                + "requires v\(minimum) or newer."
        }
    }
}

public struct WindowPresentationDiagnostic: Equatable, Sendable, CustomStringConvertible {
    public let operation: WindowPresentationOperation
    public let error: PresentationError

    public init(
        operation diagnosticOperation: WindowPresentationOperation,
        error presentationError: PresentationError
    ) {
        operation = diagnosticOperation
        error = presentationError
    }

    public var description: String {
        error.description
    }
}

public struct WindowScaleDiagnostic: Equatable, Sendable, CustomStringConvertible {
    public let operation: WindowScaleOperation
    public let reason: WindowScaleFailure

    public init(
        operation diagnosticOperation: WindowScaleOperation,
        reason diagnosticReason: WindowScaleFailure
    ) {
        operation = diagnosticOperation
        reason = diagnosticReason
    }

    public var description: String {
        reason.description
    }
}

public enum WindowScaleFailure: Equatable, Sendable, CustomStringConvertible {
    case viewporterMissing

    public var description: String {
        switch self {
        case .viewporterMissing:
            "Fractional scale protocol is available, but viewporter is missing."
        }
    }
}
