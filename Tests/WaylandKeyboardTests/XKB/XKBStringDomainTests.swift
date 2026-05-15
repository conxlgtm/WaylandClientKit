import Testing

@testable import WaylandKeyboard

@Suite
struct XKBStringDomainTests {
    @Test
    func xkbASCIITrimmedRemovesOnlyASCIIBoundaryWhitespace() {
        #expect(" \t\nsv_SE.UTF-8\r ".xkbASCIITrimmed == "sv_SE.UTF-8")
        #expect("\u{00a0}sv_SE.UTF-8\u{00a0}".xkbASCIITrimmed == "\u{00a0}sv_SE.UTF-8\u{00a0}")
    }

    @Test
    func containsNULByteReportsUTF8NUL() {
        #expect("en_US\0.UTF-8".containsNULByte)
        #expect(!"en_US.UTF-8".containsNULByte)
    }

    @Test
    func xkbKeyTextResultCommitsTextWithKeysymFacts() {
        let keysym = KeyboardKeysym(rawValue: 0x71)

        #expect(
            KeyboardTextResult.xkbKey(
                "q",
                resultKeysym: keysym,
                resultKeysymName: "q"
            )
                == .committed(
                    KeyboardTextCommit(
                        string: "q",
                        source: .xkbKey,
                        resultKeysym: keysym,
                        resultKeysymName: "q"
                    )
                )
        )
    }

    @Test
    func xkbKeyTextResultWithoutTextIsNone() {
        #expect(
            KeyboardTextResult.xkbKey(
                nil,
                resultKeysym: KeyboardKeysym(rawValue: 0x71),
                resultKeysymName: "q"
            ) == .none
        )
    }
}
