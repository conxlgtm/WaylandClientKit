import Testing

@testable import WaylandClient

@Suite
struct InterpretedKeyboardKeyEventSymbolTests {
    @Test
    func cannotCreateInterpretedKeyEventWithDisagreeingPrimarySymbol() {
        #expect(
            throws: KeyboardSymbolResolutionError.primaryNotFirst(
                primary: KeyboardKeysym(rawValue: 0x61),
                first: KeyboardKeysym(rawValue: 0x62)
            )
        ) {
            try KeyboardSymbolResolution(
                primary: KeyboardKeysym(rawValue: 0x61),
                all: [KeyboardKeysym(rawValue: 0x62)]
            )
        }
    }

    @Test
    func noSymbolKeyHasExplicitNoSymbolResolution() {
        let key = InterpretedKeyboardKeyEvent(
            serial: 10,
            time: 11,
            rawKeycode: 0,
            xkbKeycode: 8,
            symbolResolution: .resolved([]),
            interpretation: .released(keysymName: nil)
        )

        #expect(key.keysym == .noSymbol)
        #expect(key.keySymbols == [.noSymbol])
        #expect(key.primaryKeySymbol == .noSymbol)
    }

    @Test
    func multiSymbolKeyPreservesAllSymbolsAndSinglePrimaryRule() throws {
        let key = InterpretedKeyboardKeyEvent(
            serial: 10,
            time: 11,
            rawKeycode: 16,
            xkbKeycode: 24,
            symbolResolution: try KeyboardSymbolResolution(
                primary: KeyboardKeysym(rawValue: 0x61),
                all: [
                    KeyboardKeysym(rawValue: 0x61),
                    KeyboardKeysym(rawValue: 0x62),
                ]
            ),
            interpretation: .pressed(
                keysymName: "a",
                utf8: "a",
                repeatCapability: .repeating
            )
        )

        #expect(key.keysym == KeyboardKeysym(rawValue: 0x61))
        #expect(key.primaryKeySymbol == KeyboardKeysym(rawValue: 0x61))
        #expect(
            key.keySymbols == [
                KeyboardKeysym(rawValue: 0x61),
                KeyboardKeysym(rawValue: 0x62),
            ])
    }
}
