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
}
