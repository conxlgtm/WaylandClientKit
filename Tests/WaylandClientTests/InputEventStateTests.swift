import Testing

@testable import WaylandClient

@Suite
struct InputEventStateTests {
    @Test
    func buttonStateDecodesKnownAndUnknownRawValues() {
        #expect(ButtonState(rawValue: 0) == .released)
        #expect(ButtonState(rawValue: 1) == .pressed)
        #expect(ButtonState(rawValue: 99) == .unknown(99))
        #expect(ButtonState.unknown(99).rawValue == 99)
    }

    @Test
    func keyboardKeymapFormatDecodesKnownAndUnknownRawValues() {
        #expect(KeyboardKeymapFormat(rawValue: 0) == .noKeymap)
        #expect(KeyboardKeymapFormat(rawValue: 1) == .xkbV1)
        #expect(KeyboardKeymapFormat(rawValue: 99) == .unknown(99))
        #expect(KeyboardKeymapFormat.unknown(99).rawValue == 99)
    }

    @Test
    func keyStateDecodesKnownAndUnknownRawValues() {
        #expect(KeyState(rawValue: 0) == .released)
        #expect(KeyState(rawValue: 1) == .pressed)
        #expect(KeyState(rawValue: 2) == .repeated)
        #expect(KeyState(rawValue: 99) == .unknown(99))
        #expect(KeyState.unknown(99).rawValue == 99)
    }

    @Test
    func interpretedKeyStateDecodesKnownAndUnknownRawValues() {
        #expect(InterpretedKeyboardKeyState(rawValue: 0) == .released)
        #expect(InterpretedKeyboardKeyState(rawValue: 1) == .pressed)
        #expect(InterpretedKeyboardKeyState(rawValue: 2) == .repeated)
        #expect(InterpretedKeyboardKeyState(rawValue: 99) == .unknown(99))
        #expect(InterpretedKeyboardKeyState.unknown(99).rawValue == 99)
    }

    @Test
    func pointerAxisDecodesKnownAndUnknownRawValues() {
        #expect(PointerAxis(rawValue: 0) == .verticalScroll)
        #expect(PointerAxis(rawValue: 1) == .horizontalScroll)
        #expect(PointerAxis(rawValue: 99) == .unknown(99))
        #expect(PointerAxis.unknown(99).rawValue == 99)
    }

    @Test
    func pointerAxisSourceDecodesKnownAndUnknownRawValues() {
        #expect(PointerAxisSource(rawValue: 0) == .wheel)
        #expect(PointerAxisSource(rawValue: 1) == .finger)
        #expect(PointerAxisSource(rawValue: 2) == .continuous)
        #expect(PointerAxisSource(rawValue: 3) == .wheelTilt)
        #expect(PointerAxisSource(rawValue: 99) == .unknown(99))
        #expect(PointerAxisSource.unknown(99).rawValue == 99)
    }

    @Test
    func pointerAxisRelativeDirectionDecodesKnownAndUnknownRawValues() {
        #expect(PointerAxisRelativeDirection(rawValue: 0) == .identical)
        #expect(PointerAxisRelativeDirection(rawValue: 1) == .inverted)
        #expect(PointerAxisRelativeDirection(rawValue: 99) == .unknown(99))
        #expect(PointerAxisRelativeDirection.unknown(99).rawValue == 99)
    }

    @Test
    func seatSnapshotRejectsActiveCapabilityNotAdvertised() {
        #expect(
            throws: SeatStateSnapshotError.activeCapabilityNotAdvertised(
                activeCapabilities: [.keyboard],
                advertisedCapabilities: []
            )
        ) {
            _ = try SeatStateSnapshot(
                advertisedCapabilities: [],
                activeCapabilities: [.keyboard],
                name: nil
            )
        }
    }

    @Test
    func seatCapabilitiesDescriptionIncludesUnknownBits() {
        let capabilities = SeatCapabilities(rawValue: 0x80)

        #expect(capabilities.unknownBits == 0x80)
        #expect(capabilities.description == "unknown(0x80)")
        #expect(SeatCapabilities(rawValue: 0x82).description == "keyboard+unknown(0x80)")
    }

    @Test
    func inputPipelineOverflowRejectsNonPositiveCapacity() {
        #expect(throws: InputPipelineOverflowError.nonPositiveCapacity(0)) {
            _ = try InputPipelineOverflow(stage: .sessionPendingInput, capacity: 0)
        }

        #expect(throws: InputPipelineOverflowError.nonPositiveCapacity(-1)) {
            _ = try InputPipelineCapacity(-1)
        }
    }

    @Test
    func keyboardModifierDomainValuesPreserveRawValues() {
        #expect(KeyboardModifierMask(rawValue: 7).rawValue == 7)
        #expect(KeyboardLayoutGroup(rawValue: 3).rawValue == 3)
        #expect(
            KeyboardModifiers(
                serial: InputSerial(rawValue: 1),
                depressed: 2,
                latched: 3,
                locked: 4,
                group: 5
            )
            .depressed == KeyboardModifierMask(rawValue: 2)
        )
    }

    @Test
    func touchIDPreservesRawValue() {
        let id = TouchID(rawValue: 7)

        #expect(id.rawValue == 7)
        #expect(TouchID(rawValue: 7) == 7)
    }
}
