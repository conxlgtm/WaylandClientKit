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
    case pointer(RawPointerEvent)
    case keyboard(RawKeyboardEvent)
    case touch(RawTouchEvent)
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
