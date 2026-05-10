public struct InputDiagnostic: Equatable, Sendable {
    public let payload: InputDiagnosticPayload

    public init(_ diagnosticPayload: InputDiagnosticPayload) {
        payload = diagnosticPayload
    }

    public var operation: InputDiagnosticOperation {
        payload.operation
    }

    public var message: String {
        payload.description
    }
}

public enum InputDiagnosticPayload: Equatable, Sendable {
    case keymap(KeymapDiagnostic)
    case keyboardRepeat(KeyboardRepeatDiagnostic)
    case listener(InputListenerDiagnostic)
    case seatBinding(InputSeatBindingDiagnostic)
    case inputPipelineOverflow(InputPipelineOverflow)
    case cursor(CursorDiagnostic)
    case unknownProtocolValue(UnknownInputProtocolValueDiagnostic)

    public var operation: InputDiagnosticOperation {
        switch self {
        case .keymap:
            .keyboardKeymap
        case .keyboardRepeat:
            .keyboardRepeat
        case .listener(let diagnostic):
            .listener(diagnostic.listener)
        case .seatBinding(let diagnostic):
            .seatBinding(diagnostic.interface)
        case .inputPipelineOverflow(let overflow):
            .inputPipelineOverflow(overflow)
        case .cursor(let diagnostic):
            .cursor(diagnostic.operation)
        case .unknownProtocolValue(let diagnostic):
            .unknownProtocolValue(diagnostic.field)
        }
    }
}

extension InputDiagnosticPayload: CustomStringConvertible {
    public var description: String {
        switch self {
        case .keymap(let diagnostic):
            diagnostic.description
        case .keyboardRepeat(let diagnostic):
            diagnostic.description
        case .listener(let diagnostic):
            diagnostic.description
        case .seatBinding(let diagnostic):
            diagnostic.description
        case .inputPipelineOverflow(let overflow):
            "\(overflow.stage.description) exceeded capacity \(overflow.capacity)"
        case .cursor(let diagnostic):
            diagnostic.description
        case .unknownProtocolValue(let diagnostic):
            diagnostic.description
        }
    }
}

public enum KeymapDiagnostic: Equatable, Sendable, CustomStringConvertible {
    case readFailed(KeymapReadFailure)

    public var description: String {
        switch self {
        case .readFailed(let failure):
            failure.description
        }
    }
}

public struct KeyboardRepeatDiagnostic: Equatable, Sendable, CustomStringConvertible {
    public let failure: KeyboardRepeatFailure

    public init(_ diagnosticFailure: KeyboardRepeatFailure) {
        failure = diagnosticFailure
    }

    public var description: String {
        failure.description
    }
}

public enum KeyboardRepeatFailure: Equatable, Sendable, CustomStringConvertible {
    case negativeRate(rate: Int32, delay: Int32)
    case negativeDelay(rate: Int32, delay: Int32)

    public var description: String {
        switch self {
        case .negativeRate(let rate, let delay):
            "invalid keyboard repeat info: negative rate \(rate), delay \(delay)"
        case .negativeDelay(let rate, let delay):
            "invalid keyboard repeat info: rate \(rate), negative delay \(delay)"
        }
    }
}

public enum KeymapReadFailure: Equatable, Sendable, CustomStringConvertible {
    case unsupportedFormat(format: KeyboardKeymapFormat, advertisedSize: UInt32)
    case invalidFileDescriptor(Int32)
    case invalidSizeLimit(maxSize: UInt32, hardMaximumSize: UInt32)
    case emptyXKBV1Payload(size: UInt32)
    case tooLarge(size: UInt32, maxSize: UInt32)
    case tooLargeForProtocolSize(Int)
    case fdTooSmall(size: UInt32, actualSize: Int64)
    case missingNULTerminator(size: UInt32)
    case system(WaylandSystemError)

    public var description: String {
        switch self {
        case .unsupportedFormat(let format, let advertisedSize):
            "unsupported keymap format \(format.rawValue) with advertised size \(advertisedSize)"
        case .invalidFileDescriptor(let descriptor):
            "invalid keymap file descriptor \(descriptor)"
        case .invalidSizeLimit(let maxSize, let hardMaximumSize):
            "invalid keymap size limit \(maxSize); maximum supported limit is \(hardMaximumSize)"
        case .emptyXKBV1Payload(let size):
            "empty xkb_v1 keymap payload with advertised size \(size)"
        case .tooLarge(let size, let maxSize):
            "keymap size \(size) exceeds configured maximum \(maxSize)"
        case .tooLargeForProtocolSize(let byteCount):
            "keymap byte count \(byteCount) exceeds UInt32"
        case .fdTooSmall(let size, let actualSize):
            "keymap fd contains \(actualSize) bytes, fewer than advertised size \(size)"
        case .missingNULTerminator(let size):
            "xkb_v1 keymap of size \(size) is not NUL-terminated"
        case .system(let error):
            "system error during keymap read: \(error.description)"
        }
    }
}

public struct InputListenerDiagnostic: Equatable, Sendable, CustomStringConvertible {
    public let listener: String
    public let message: String

    public init(listener listenerName: String, message diagnosticMessage: String) {
        listener = listenerName
        message = diagnosticMessage
    }

    public var description: String {
        message
    }
}

public struct InputSeatBindingDiagnostic: Equatable, Sendable, CustomStringConvertible {
    public let interface: String
    public let failure: InputSeatBindingFailure

    public init(interface interfaceName: String, failure bindingFailure: InputSeatBindingFailure) {
        interface = interfaceName
        failure = bindingFailure
    }

    public var description: String {
        "\(interface) binding failed: \(failure.description)"
    }
}

public enum InputSeatBindingFailure: Equatable, Sendable, CustomStringConvertible {
    case bindFailed(interface: String)
    case listener(InputSeatBindingListener)
    case proxyQueueMismatch(interface: String, objectID: UInt32?)
    case system(WaylandSystemError)
    case systemErrnoUnavailable(WaylandSystemOperation)
    case other(String)

    public var description: String {
        switch self {
        case .bindFailed(let interface):
            "Failed to bind global: \(interface)"
        case .listener(let listener):
            listener.description
        case .proxyQueueMismatch(let interface, let objectID):
            "\(interface) proxy \(objectID.map { "id=\($0)" } ?? "?") "
                + "is not assigned to the display owner event queue"
        case .system(let error):
            "Wayland runtime failed with \(error.description)"
        case .systemErrnoUnavailable(let operation):
            "Wayland runtime failed during \(operation.description) without errno"
        case .other(let message):
            message
        }
    }
}

public enum InputSeatBindingListener: Equatable, Sendable, CustomStringConvertible {
    case registry
    case output
    case seat
    case pointer
    case keyboard
    case touch
    case syncCallback

    public var description: String {
        switch self {
        case .registry:
            "Wayland registry listener installation failed"
        case .output:
            "Wayland output listener installation failed"
        case .seat:
            "Wayland seat listener installation failed"
        case .pointer:
            "Wayland pointer listener installation failed"
        case .keyboard:
            "Wayland keyboard listener installation failed"
        case .touch:
            "Wayland touch listener installation failed"
        case .syncCallback:
            "Wayland sync callback listener installation failed"
        }
    }
}

public enum CursorDiagnosticOperation: Equatable, Sendable {
    case missingCursor
    case automaticPointerEnter
}

public enum AutomaticPointerEnterFailure: Error, Equatable, Sendable, CustomStringConvertible {
    case cursorImageResolution(String)
    case cursorSurfaceCreation(String)
    case cursorRequest(PointerCursorRequestFailure)
    case cursorApplication(String)

    public var description: String {
        switch self {
        case .cursorImageResolution(let detail):
            "cursor image resolution failed: \(detail)"
        case .cursorSurfaceCreation(let detail):
            "cursor surface creation failed: \(detail)"
        case .cursorRequest(let failure):
            failure.description
        case .cursorApplication(let detail):
            "cursor application failed: \(detail)"
        }
    }
}

public enum CursorDiagnostic: Equatable, Sendable, CustomStringConvertible {
    case missingCursor(name: String)
    case automaticPointerEnterFailed(AutomaticPointerEnterFailure)

    public var operation: CursorDiagnosticOperation {
        switch self {
        case .missingCursor:
            .missingCursor
        case .automaticPointerEnterFailed:
            .automaticPointerEnter
        }
    }

    public var description: String {
        switch self {
        case .missingCursor(let name):
            "cursor \(name) is unavailable"
        case .automaticPointerEnterFailed(let failure):
            failure.description
        }
    }
}

public enum UnknownInputProtocolValueField: Equatable, Hashable, Sendable,
    CustomStringConvertible
{
    case pointerAxis
    case pointerAxisSource
    case pointerAxisRelativeDirection
    case pointerButtonState
    case keyboardKeyState
    case seatCapability

    public var description: String {
        switch self {
        case .pointerAxis:
            "pointer axis"
        case .pointerAxisSource:
            "pointer axis source"
        case .pointerAxisRelativeDirection:
            "pointer axis relative direction"
        case .pointerButtonState:
            "pointer button state"
        case .keyboardKeyState:
            "keyboard key state"
        case .seatCapability:
            "seat capability"
        }
    }
}

public struct UnknownInputProtocolValueDiagnostic: Equatable, Sendable,
    CustomStringConvertible
{
    public let field: UnknownInputProtocolValueField
    public let rawValue: UInt32
    public let seatID: SeatID
    public let sequence: UInt64

    public init(
        field diagnosticField: UnknownInputProtocolValueField,
        rawValue diagnosticRawValue: UInt32,
        seatID diagnosticSeatID: SeatID,
        sequence diagnosticSequence: UInt64
    ) {
        field = diagnosticField
        rawValue = diagnosticRawValue
        seatID = diagnosticSeatID
        sequence = diagnosticSequence
    }

    public var description: String {
        "unknown \(field.description) \(rawValue) from \(seatID) at input sequence \(sequence)"
    }
}

public enum InputDiagnosticOperation: Equatable, Sendable {
    case keyboardKeymap
    case keyboardRepeat
    case listener(String)
    case seatBinding(String)
    case inputPipelineOverflow(InputPipelineOverflow)
    case cursor(CursorDiagnosticOperation)
    case unknownProtocolValue(UnknownInputProtocolValueField)
}
