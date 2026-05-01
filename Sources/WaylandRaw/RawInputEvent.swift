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
    public let operation: RawInputDiagnosticOperation
    public let message: String

    public init(
        operation diagnosticOperation: RawInputDiagnosticOperation,
        message detail: String
    ) {
        operation = diagnosticOperation
        message = detail
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
