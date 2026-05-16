import Testing

@testable import WaylandRaw

@Suite
struct RawInputDeviceIDOrderingTests {
    @Test
    func sortsBySeatKindRankAndGeneration() {
        let secondSeatKeyboard = RawInputDeviceID(
            seatID: RawSeatID(rawValue: 2),
            kind: .keyboard,
            generation: 1
        )
        let firstSeatTouch = RawInputDeviceID(
            seatID: RawSeatID(rawValue: 1),
            kind: .touch,
            generation: 1
        )
        let firstSeatPointerSecondGeneration = RawInputDeviceID(
            seatID: RawSeatID(rawValue: 1),
            kind: .pointer,
            generation: 2
        )
        let firstSeatPointerFirstGeneration = RawInputDeviceID(
            seatID: RawSeatID(rawValue: 1),
            kind: .pointer,
            generation: 1
        )
        let firstSeatKeyboard = RawInputDeviceID(
            seatID: RawSeatID(rawValue: 1),
            kind: .keyboard,
            generation: 1
        )

        let sorted = [
            secondSeatKeyboard,
            firstSeatTouch,
            firstSeatPointerSecondGeneration,
            firstSeatKeyboard,
            firstSeatPointerFirstGeneration,
        ].sortedByInputDeviceIdentity()

        #expect(
            sorted == [
                firstSeatPointerFirstGeneration,
                firstSeatPointerSecondGeneration,
                firstSeatKeyboard,
                firstSeatTouch,
                secondSeatKeyboard,
            ]
        )
    }
}
