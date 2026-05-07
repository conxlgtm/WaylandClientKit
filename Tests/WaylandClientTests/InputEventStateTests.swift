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
    func touchIDPreservesRawValue() {
        let id = TouchID(rawValue: 7)

        #expect(id.rawValue == 7)
        #expect(TouchID(rawValue: 7) == 7)
    }
}
