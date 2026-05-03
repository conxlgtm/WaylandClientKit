public struct RawInputEvent: Equatable, Sendable {
    public let sequence: UInt64
    public let seatID: RawSeatID
    public let deviceID: RawInputDeviceID?
    public let kind: RawInputEventKind

    public init(
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

public enum RawInputEventKind: Equatable, Sendable {
    case seat(RawSeatEventSnapshot)
    case seatRemoved
    case diagnostic(RawInputDiagnostic)
    case pointer(RawPointerEvent)
    case keyboard(RawKeyboardEvent)
    case touch(RawTouchEvent)
}

public struct RawInputDiagnostic: Equatable, Sendable {
    public let payload: RawInputDiagnosticPayload

    public init(_ diagnosticPayload: RawInputDiagnosticPayload) {
        payload = diagnosticPayload
    }

    public var operation: RawInputDiagnosticOperation {
        payload.operation
    }

    public var message: String {
        payload.description
    }
}

public enum RawInputDiagnosticPayload: Equatable, Sendable {
    case keymap(RawKeymapDiagnostic)
    case listener(RawListenerDiagnostic)
    case queueOverflow(RawInputPipelineOverflow)
    case inputPipelineOverflow(RawInputPipelineOverflow)

    public var operation: RawInputDiagnosticOperation {
        switch self {
        case .keymap:
            .keyboardKeymap
        case .listener(let diagnostic):
            .listener(diagnostic.listener)
        case .queueOverflow:
            .queueOverflow
        case .inputPipelineOverflow(let overflow):
            .inputPipelineOverflow(overflow)
        }
    }
}

extension RawInputDiagnosticPayload: CustomStringConvertible {
    public var description: String {
        switch self {
        case .keymap(let diagnostic):
            diagnostic.description
        case .listener(let diagnostic):
            diagnostic.description
        case .queueOverflow(let overflow):
            "\(overflow.stage.description) exceeded capacity \(overflow.capacity)"
        case .inputPipelineOverflow(let overflow):
            "\(overflow.stage.description) exceeded capacity \(overflow.capacity)"
        }
    }
}

public enum RawKeymapDiagnostic: Equatable, Sendable, CustomStringConvertible {
    case readFailed(id: RawKeyboardKeymapID, error: RawKeyboardKeymapReadError)

    public var description: String {
        switch self {
        case .readFailed(_, let error):
            error.description
        }
    }
}

public struct RawListenerDiagnostic: Equatable, Sendable, CustomStringConvertible {
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

public enum RawInputDiagnosticOperation: Equatable, Sendable {
    case keyboardKeymap
    case listener(String)
    case queueOverflow
    case inputPipelineOverflow(RawInputPipelineOverflow)
}

public enum RawInputPipelineOverflowStage: Equatable, Sendable {
    case rawInputQueue
}

extension RawInputPipelineOverflowStage: CustomStringConvertible {
    public var description: String {
        switch self {
        case .rawInputQueue:
            "raw input queue"
        }
    }
}

public struct RawInputPipelineOverflow: Equatable, Sendable {
    public let stage: RawInputPipelineOverflowStage
    public let capacity: Int

    public init(stage overflowStage: RawInputPipelineOverflowStage, capacity queueCapacity: Int) {
        stage = overflowStage
        capacity = queueCapacity
    }
}

public struct RawSeatEventSnapshot: Equatable, Sendable {
    public let advertisedCapabilities: SeatCapabilities
    public let activeCapabilities: SeatCapabilities
    public let name: String?

    public init(
        advertisedCapabilities seatAdvertisedCapabilities: SeatCapabilities,
        activeCapabilities seatActiveCapabilities: SeatCapabilities,
        name seatName: String?
    ) {
        advertisedCapabilities = seatAdvertisedCapabilities
        activeCapabilities = seatActiveCapabilities
        name = seatName
    }
}
