public enum WindowError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidConfigure(WindowConfigureError)
    case invalidLifecycleTransition(WindowLifecycleTransitionError)
    case initialConfigureTimedOut(milliseconds: Int32)
    case presentationFailed(PresentationError)

    public var description: String {
        switch self {
        case .invalidConfigure(let error):
            "Invalid window configure: \(error.description)"
        case .invalidLifecycleTransition(let error):
            "Invalid window lifecycle transition: \(error.description)"
        case .initialConfigureTimedOut(let milliseconds):
            "Timed out waiting for initial configure after \(milliseconds) ms"
        case .presentationFailed(let error):
            "Window presentation failed: \(error.description)"
        }
    }
}

public enum WindowConfigurationError: Equatable, Sendable, CustomStringConvertible {
    case nonPositiveInitialWidth(Int32)
    case nonPositiveInitialHeight(Int32)
    case nonPositiveBufferCount(Int)
    case negativeMilliseconds(value: Int32)
    case emptyString(field: String)
    case interiorNUL(field: String)
    case nonPositiveInt32(value: Int32)
    case nonPositiveInt(value: Int)
    case nonPositiveScaleNumerator(UInt32)
    case zeroScaleDenominator

    public var description: String {
        switch self {
        case .nonPositiveInitialWidth(let value):
            "initialWidth must be greater than zero, got \(value)"
        case .nonPositiveInitialHeight(let value):
            "initialHeight must be greater than zero, got \(value)"
        case .nonPositiveBufferCount(let value):
            "bufferCount must be greater than zero, got \(value)"
        case .negativeMilliseconds(let value):
            "milliseconds must be greater than or equal to zero, got \(value)"
        case .emptyString(let field):
            "\(field) must not be empty"
        case .interiorNUL(let field):
            "\(field) must not contain embedded NUL bytes"
        case .nonPositiveInt32(let value):
            "expected positive Int32, got \(value)"
        case .nonPositiveInt(let value):
            "expected positive Int, got \(value)"
        case .nonPositiveScaleNumerator(let value):
            "scale numerator must be greater than zero, got \(value)"
        case .zeroScaleDenominator:
            "scale denominator must be greater than zero"
        }
    }
}

public enum WindowConfigureError: Equatable, Sendable, CustomStringConvertible {
    case negativeSuggestedDimension(width: Int32, height: Int32)
    case unresolvedSize
    case invalidSerial(UInt32)
    case invalidDecorationMode(UInt32)

    public var description: String {
        switch self {
        case .negativeSuggestedDimension(let width, let height):
            "xdg_toplevel.configure suggested negative dimensions width=\(width) height=\(height)"
        case .unresolvedSize:
            "configure size could not be resolved"
        case .invalidSerial(let serial):
            "invalid configure serial \(serial)"
        case .invalidDecorationMode(let rawValue):
            "invalid zxdg_toplevel_decoration_v1 mode \(rawValue)"
        }
    }
}

public enum WindowLifecycleTransitionError: Equatable, Sendable, CustomStringConvertible {
    case mapBeforeInitialConfigure
    case redrawAfterDestroyed
    case presentWhileClosing
    case closeAfterDestroyed
    case presentWithoutRedrawRequest
    case nestedPresentation
    case presentAfterDestroyed
    case inactivePresentationCompletion
    case presentationGenerationMismatch(expected: UInt64, actual: UInt64)
    case invalidTransition(from: String, event: String)

    public var description: String {
        switch self {
        case .mapBeforeInitialConfigure:
            "cannot map before the initial configure is acknowledged"
        case .redrawAfterDestroyed:
            "cannot redraw after the window is destroyed"
        case .presentWhileClosing:
            "cannot present while the window is closing"
        case .closeAfterDestroyed:
            "cannot close after the window is destroyed"
        case .presentWithoutRedrawRequest:
            "cannot present without a redraw request"
        case .nestedPresentation:
            "cannot present while another presentation is active"
        case .presentAfterDestroyed:
            "cannot present after the window is destroyed"
        case .inactivePresentationCompletion:
            "cannot complete presentation because no presentation is active"
        case .presentationGenerationMismatch(let expected, let actual):
            "cannot complete presentation generation \(actual); active generation is \(expected)"
        case .invalidTransition(let state, let event):
            "cannot apply \(event) while \(state)"
        }
    }
}

public enum PresentationError: Error, Equatable, Sendable, CustomStringConvertible {
    case noFreeBuffer
    case drawFailed(String)

    public var description: String {
        switch self {
        case .noFreeBuffer:
            "no free buffer is available"
        case .drawFailed(let detail):
            detail
        }
    }
}
