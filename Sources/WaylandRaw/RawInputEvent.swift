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
    case pointer(RawPointerEvent)
    case keyboard(RawKeyboardEvent)
    case touch(RawTouchEvent)
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
