package struct RawInputEvent: Equatable, Sendable {
    package let sequence: UInt64
    package let seatID: RawSeatID
    package let deviceID: RawInputDeviceID?
    package let kind: RawInputEventKind

    package init(
        sequence eventSequence: UInt64,
        seatID eventSeatID: RawSeatID,
        deviceID eventDeviceID: RawInputDeviceID?,
        kind eventKind: RawInputEventKind
    ) {
        sequence = eventSequence
        seatID = eventSeatID
        deviceID = eventDeviceID
        kind = eventKind
    }
}

package struct RawInputEventDraft: Equatable, Sendable {
    package let seatID: RawSeatID
    package let deviceID: RawInputDeviceID?
    package let kind: RawInputEventKind

    package init(
        seatID eventSeatID: RawSeatID,
        deviceID eventDeviceID: RawInputDeviceID?,
        kind eventKind: RawInputEventKind
    ) {
        seatID = eventSeatID
        deviceID = eventDeviceID
        kind = eventKind
    }
}

package enum RawInputEventKind: Equatable, Sendable {
    case seat(RawSeatEventSnapshot)
    case seatRemoved
    case diagnostic(RawInputDiagnostic)
    case pointer(RawPointerEvent)
    case keyboard(RawKeyboardEvent)
    case touch(RawTouchEvent)
}

package struct RawInputDiagnostic: Equatable, Sendable {
    package let payload: RawInputDiagnosticPayload

    package init(_ diagnosticPayload: RawInputDiagnosticPayload) {
        payload = diagnosticPayload
    }

    package var operation: RawInputDiagnosticOperation {
        payload.operation
    }

    package var message: String {
        payload.description
    }
}

package enum RawInputDiagnosticPayload: Equatable, Sendable {
    case keymap(RawKeymapDiagnostic)
    case keyboardRepeat(RawKeyboardRepeatDiagnostic)
    case listener(RawListenerDiagnostic)
    case seatBinding(RawSeatBindingDiagnostic)
    case inputPipelineOverflow(RawInputPipelineOverflow)

    package var operation: RawInputDiagnosticOperation {
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
        }
    }
}

extension RawInputDiagnosticPayload: CustomStringConvertible {
    package var description: String {
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
        }
    }
}

package enum RawKeymapDiagnostic: Equatable, Sendable, CustomStringConvertible {
    case readFailed(id: RawKeyboardKeymapID, error: RawKeyboardKeymapReadError)

    package var description: String {
        switch self {
        case .readFailed(_, let error):
            error.description
        }
    }
}

package struct RawKeyboardRepeatDiagnostic: Equatable, Sendable, CustomStringConvertible {
    package let error: RawKeyboardRepeatInfoError

    package init(error repeatError: RawKeyboardRepeatInfoError) {
        error = repeatError
    }

    package var description: String {
        error.description
    }
}

package struct RawListenerDiagnostic: Equatable, Sendable, CustomStringConvertible {
    package let listener: String
    package let message: String

    package init(listener listenerName: String, message diagnosticMessage: String) {
        listener = listenerName
        message = diagnosticMessage
    }

    package var description: String {
        message
    }
}

package struct RawSeatBindingDiagnostic: Equatable, Sendable, CustomStringConvertible {
    package let interface: String
    package let failure: RawSeatBindingFailure

    package init(interface interfaceName: String, failure bindingFailure: RawSeatBindingFailure) {
        interface = interfaceName
        failure = bindingFailure
    }

    package init(interface interfaceName: String, error bindingError: RuntimeError) {
        self.init(interface: interfaceName, failure: RawSeatBindingFailure(bindingError))
    }

    package var description: String {
        "\(interface) binding failed: \(failure.description)"
    }
}

package enum RawSeatBindingFailure: Equatable, Sendable, CustomStringConvertible {
    case bindFailed(String)
    case listener(RawListenerInstallationError)
    case proxy(RawProxyError)
    case system(RawSystemError)
    case systemErrnoUnavailable(RawSystemOperation)
    case other(String)

    package init(_ runtimeError: RuntimeError) {
        switch runtimeError {
        case .bindFailed(let interfaceName):
            self = .bindFailed(interfaceName)
        case .listener(let error):
            self = .listener(error)
        case .proxy(let error):
            self = .proxy(error)
        case .system(let error):
            self = .system(error)
        case .systemErrnoUnavailable(let operation):
            self = .systemErrnoUnavailable(operation)
        default:
            self = .other(runtimeError.description)
        }
    }

    package var description: String {
        switch self {
        case .bindFailed(let interfaceName):
            "Failed to bind global: \(interfaceName)"
        case .listener(let error):
            error.description
        case .proxy(let error):
            error.description
        case .system(let error):
            "Wayland runtime failed with \(error.description)"
        case .systemErrnoUnavailable(let operation):
            "Wayland runtime failed during \(operation.description) without errno"
        case .other(let message):
            message
        }
    }
}

package enum RawInputDiagnosticOperation: Equatable, Sendable {
    case keyboardKeymap
    case keyboardRepeat
    case listener(String)
    case seatBinding(String)
    case inputPipelineOverflow(RawInputPipelineOverflow)
}

package enum RawInputPipelineOverflowStage: Equatable, Sendable {
    case rawInputQueue
}

extension RawInputPipelineOverflowStage: CustomStringConvertible {
    package var description: String {
        switch self {
        case .rawInputQueue:
            "raw input queue"
        }
    }
}

package struct RawInputPipelineOverflow: Equatable, Sendable {
    package let stage: RawInputPipelineOverflowStage
    package let capacity: Int

    package init(stage overflowStage: RawInputPipelineOverflowStage, capacity queueCapacity: Int) {
        stage = overflowStage
        capacity = queueCapacity
    }
}

package struct RawSeatEventSnapshot: Equatable, Sendable {
    package let advertisedCapabilities: SeatCapabilities
    package let activeCapabilities: SeatCapabilities
    package let name: String?

    package init(
        advertisedCapabilities seatAdvertisedCapabilities: SeatCapabilities,
        activeCapabilities seatActiveCapabilities: SeatCapabilities,
        name seatName: String?
    ) {
        advertisedCapabilities = seatAdvertisedCapabilities
        activeCapabilities = seatActiveCapabilities
        name = seatName
    }
}
