import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct InputDomainValuesRawTests {
    @Test
    func seatAndOutputIDsPreserveRawValues() {
        let rawSeatID = RawSeatID(rawValue: 7)
        let seatID = SeatID(rawSeatID)
        #expect(seatID.rawValue == rawSeatID.rawValue)
        #expect(RawSeatID(seatID) == rawSeatID)

        let rawOutputID = RawOutputID(rawValue: 9)
        let outputID = OutputID(rawOutputID)
        #expect(outputID.rawValue == rawOutputID.rawValue)
        #expect(RawOutputID(outputID) == rawOutputID)
    }

    @Test
    func inputEnumsPreserveUnknownRawValues() {
        #expect(ButtonState(RawPointerButtonState(rawValue: 44)) == .unknown(44))
        #expect(KeyState(RawKeyboardKeyState(rawValue: 45)) == .unknown(45))
        #expect(KeyboardKeymapFormat(RawKeyboardKeymapFormat(rawValue: 46)) == .unknown(46))
        #expect(PointerAxis(RawPointerAxis(rawValue: 47)) == .unknown(47))
        #expect(PointerAxisSource(RawPointerAxisSource(rawValue: 48)) == .unknown(48))
        #expect(
            PointerAxisRelativeDirection(RawPointerAxisRelativeDirection(rawValue: 49))
                == .unknown(49)
        )
    }

    @Test
    func seatStateSnapshotPreservesRawCapabilitiesAndName() {
        let raw = RawSeatEventSnapshot(
            uncheckedAdvertisedCapabilities: [.pointer, .keyboard],
            activeCapabilities: [.keyboard],
            name: "seat0"
        )

        #expect(
            SeatStateSnapshot(raw)
                == SeatStateSnapshot(
                    uncheckedAdvertisedCapabilities: [.pointer, .keyboard],
                    activeCapabilities: [.keyboard],
                    name: SeatName(rawValue: "seat0")
                )
        )
    }

    @Test
    func seatStateSnapshotDropsEmptyRawName() {
        let raw = RawSeatEventSnapshot(
            uncheckedAdvertisedCapabilities: [.pointer],
            activeCapabilities: [.pointer],
            name: ""
        )

        #expect(SeatStateSnapshot(raw).name == nil)
    }

    @Test
    func pointerAxisEventPreservesRawAxisFacts() {
        #expect(
            PointerAxisEvent(
                .axis(
                    time: 12,
                    axis: RawPointerAxis(rawValue: 47),
                    value: WaylandFixed(rawValue: 384)
                )
            )
                == .axis(
                    time: WaylandTimestampMilliseconds(rawValue: 12),
                    axis: .unknown(47),
                    value: 1.5
                )
        )
        #expect(
            PointerAxisEvent(.source(RawPointerAxisSource(rawValue: 48)))
                == .source(.unknown(48))
        )
        #expect(
            PointerAxisEvent(
                .stop(time: 13, axis: RawPointerAxis(rawValue: 49))
            )
                == .stop(
                    time: WaylandTimestampMilliseconds(rawValue: 13),
                    axis: .unknown(49)
                )
        )
        #expect(
            PointerAxisEvent(
                .discrete(axis: RawPointerAxis(rawValue: 50), value: -1)
            )
                == .discrete(axis: .unknown(50), value: -1)
        )
        #expect(
            PointerAxisEvent(
                .value120(axis: RawPointerAxis(rawValue: 51), value120: 120)
            )
                == .value120(axis: .unknown(51), value120: 120)
        )
        #expect(
            PointerAxisEvent(
                .relativeDirection(
                    axis: RawPointerAxis(rawValue: 52),
                    direction: RawPointerAxisRelativeDirection(rawValue: 53)
                )
            )
                == .relativeDirection(axis: .unknown(52), direction: .unknown(53))
        )
        #expect(PointerAxisEvent(.frame) == .frame)
    }

    @Test
    func pointerLocationPreservesRawFixedCoordinates() {
        #expect(
            PointerLocation(
                waylandX: WaylandFixed(rawValue: 384),
                waylandY: WaylandFixed(rawValue: -128)
            )
                == PointerLocation(x: 1.5, y: -0.5)
        )
    }
}
