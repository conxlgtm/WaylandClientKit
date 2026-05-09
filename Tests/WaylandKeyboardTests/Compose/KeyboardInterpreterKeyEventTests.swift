// swiftlint:disable file_length

import Testing
import WaylandRaw

@testable import WaylandKeyboard

@Suite
struct KeyboardInterpreterKeyEventTests {  // swiftlint:disable:this type_body_length
    @Test
    func interpreterCreatesContext() throws {
        _ = try testKeyboardInterpreter()
    }

    @Test
    func pressedKeyPreservesEvdevKeycodeAndInterpretsSymbolTextAndRepeat() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(qKey()), sequence: 2)
            )
            .first
        )
        let key = try #require(event.interpretedKey)

        #expect(event.sequence == 2)
        #expect(key.evdevKeycode == 16)
        #expect(key.xkbKeycode == 24)
        #expect(key.state == .pressed)
        #expect(key.keysymName == "q")
        #expect(key.keysyms == [KeyboardKeysym(rawValue: 0x71)])
        #expect(key.utf8 == "q")
        #expect(
            key.text
                == .committed(
                    KeyboardTextCommit(
                        string: "q",
                        source: .xkbKey,
                        resultKeysym: KeyboardKeysym(rawValue: 0x71),
                        resultKeysymName: "q"
                    )
                )
        )
        #expect(key.repeatCapability == .repeating)
    }

    @Test
    func repeatedKeyPreservesRepeatedState() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .key(qKey(state: .repeated))
                )
            ).first
        )
        let key = try #require(event.interpretedKey)

        #expect(key.state == .repeated)
        #expect(key.utf8 == "q")
        #expect(key.text.committedString == "q")
        #expect(key.repeatCapability == .repeating)
    }

    @Test
    func pressedModifierKeyReportsNonRepeatingCapability() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .key(qKey(evdevKeycode: 42))
                )
            ).first
        )
        let key = try #require(event.interpretedKey)

        #expect(key.state == .pressed)
        #expect(key.keysymName == "Shift_L")
        #expect(key.utf8 == nil)
        #expect(key.text == .none)
        #expect(key.repeatCapability == .nonRepeating)
    }

    @Test
    func releasedKeyPreservesSymbolButDoesNotProduceText() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .key(qKey(state: .released))
                )
            ).first
        )
        let key = try #require(event.interpretedKey)

        #expect(key.state == .released)
        #expect(key.keysymName == "q")
        #expect(key.utf8 == nil)
        #expect(key.text == .none)
        #expect(key.repeatCapability == nil)
        #expect(key.interpretation == .released(keysymName: "q"))
    }

    @Test
    func unknownKeyStatePreservesStateWithoutTextOrRepeatPayload() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let unknownState = RawKeyboardKeyState(rawValue: 99)
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .key(qKey(state: unknownState))
                )
            ).first
        )
        let key = try #require(event.interpretedKey)
        let interpretedState = InterpretedKeyboardKeyState(rawValue: 99)

        #expect(key.state == interpretedState)
        #expect(key.keysymName == "q")
        #expect(key.utf8 == nil)
        #expect(key.text == .none)
        #expect(key.repeatCapability == nil)
        #expect(key.interpretation == .unknown(state: interpretedState, keysymName: "q"))
    }

    @Test
    func deadKeyPressStartsComposeWithoutReplacingRawKeyIdentity() throws {
        let interpreter = try interpreterWithFixtureKeymap(
            configuration: KeyboardInterpreterConfiguration(
                compose: .tableBuffer(composeTableText())
            )
        )
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(deadAcuteKey()))
            ).first
        )
        let key = try #require(event.interpretedKey)

        #expect(key.state == .pressed)
        #expect(key.keysymName == "dead_acute")
        #expect(
            key.text
                == .composing(
                    KeyboardComposeProgress(
                        startedBy: KeyboardKeysym(rawValue: 0xFE51),
                        startedByName: "dead_acute"
                    )
                ))
    }

    @Test
    func multiStepComposeProgressPreservesStartingKeysym() throws {
        let interpreter = try interpreterWithFixtureKeymap(
            configuration: KeyboardInterpreterConfiguration(
                compose: .tableBuffer(multiStepComposeTableText())
            )
        )
        let deviceID = keyboardDevice()

        let started = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(deadAcuteKey()))
            ).first?.interpretedKey
        )
        let continued = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(bKey()))
            ).first?.interpretedKey
        )

        #expect(
            started.text
                == .composing(
                    KeyboardComposeProgress(
                        startedBy: KeyboardKeysym(rawValue: 0xFE51),
                        startedByName: "dead_acute"
                    )
                ))
        #expect(
            continued.text
                == .composing(
                    KeyboardComposeProgress(
                        startedBy: KeyboardKeysym(rawValue: 0xFE51),
                        startedByName: "dead_acute"
                    )
                ))
    }

    @Test
    func multiStepComposeProgressDoesNotReplaceStartedByWithSecondKey() throws {
        let interpreter = try interpreterWithFixtureKeymap(
            configuration: KeyboardInterpreterConfiguration(
                compose: .tableBuffer(multiStepComposeTableText())
            )
        )
        let deviceID = keyboardDevice()

        _ = interpreter.consume(
            rawKeyboardInputEvent(deviceID: deviceID, kind: .key(deadAcuteKey()))
        )
        let continued = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(bKey()))
            ).first?.interpretedKey
        )

        guard case .composing(let progress) = continued.text else {
            Issue.record("expected compose progress")
            return
        }
        #expect(progress.startedBy == KeyboardKeysym(rawValue: 0xFE51))
        #expect(progress.startedBy != KeyboardKeysym(rawValue: 0x62))
    }

    @Test
    func deadKeyThenACommitsComposedTextOnlyOnCompletingPress() throws {
        let interpreter = try interpreterWithFixtureKeymap(
            configuration: KeyboardInterpreterConfiguration(
                compose: .tableBuffer(composeTableText())
            )
        )
        let deviceID = keyboardDevice()

        _ = interpreter.consume(
            rawKeyboardInputEvent(deviceID: deviceID, kind: .key(deadAcuteKey()))
        )
        let release = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID, kind: .key(deadAcuteKey(state: .released)))
            ).first?.interpretedKey
        )
        let composed = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(aKey()))
            ).first?.interpretedKey
        )
        let finalRelease = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(aKey(state: .released)))
            ).first?.interpretedKey
        )

        #expect(release.keysymName == "dead_acute")
        #expect(release.text == .none)
        #expect(composed.keysymName == "a")
        #expect(composed.utf8 == "a")
        #expect(
            composed.text
                == .committed(
                    KeyboardTextCommit(
                        string: "á",
                        source: .compose,
                        resultKeysym: KeyboardKeysym(rawValue: 0xE1),
                        resultKeysymName: "aacute"
                    )
                ))
        #expect(finalRelease.text == .none)
    }

    @Test
    func composeCancellationPassesThroughCancellingKeyByDefault() throws {
        let interpreter = try interpreterWithFixtureKeymap(
            configuration: KeyboardInterpreterConfiguration(
                compose: .tableBuffer(composeTableText())
            )
        )
        let deviceID = keyboardDevice()

        _ = interpreter.consume(
            rawKeyboardInputEvent(deviceID: deviceID, kind: .key(deadAcuteKey()))
        )
        let cancelled = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(bKey()))
            ).first?.interpretedKey
        )

        #expect(cancelled.keysymName == "b")
        #expect(cancelled.utf8 == "b")
        #expect(
            cancelled.text
                == .cancelled(
                    KeyboardComposeCancellation(
                        cancellingKeysym: KeyboardKeysym(rawValue: 0x62),
                        cancellingKeysymName: "b",
                        fallbackCommit: KeyboardTextCommit(
                            string: "b",
                            source: .composeCancellationFallback,
                            resultKeysym: KeyboardKeysym(rawValue: 0x62),
                            resultKeysymName: "b"
                        )
                    )
                ))
    }

    @Test
    func composeCancellationCanSwallowCancellingKeyText() throws {
        let interpreter = try interpreterWithFixtureKeymap(
            configuration: KeyboardInterpreterConfiguration(
                compose: .tableBuffer(
                    composeTableText(),
                    cancellationPolicy: .swallowCancellingKey
                )
            )
        )
        let deviceID = keyboardDevice()

        _ = interpreter.consume(
            rawKeyboardInputEvent(deviceID: deviceID, kind: .key(deadAcuteKey()))
        )
        let cancelled = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(bKey()))
            ).first?.interpretedKey
        )

        #expect(
            cancelled.text
                == .cancelled(
                    KeyboardComposeCancellation(
                        cancellingKeysym: KeyboardKeysym(rawValue: 0x62),
                        cancellingKeysymName: "b",
                        fallbackCommit: nil
                    )
                ))
    }

    @Test
    func ignoredModifierKeyDoesNotCancelActiveComposeSequence() throws {
        let interpreter = try interpreterWithFixtureKeymap(
            configuration: KeyboardInterpreterConfiguration(
                compose: .tableBuffer(composeTableText())
            )
        )
        let deviceID = keyboardDevice()

        _ = interpreter.consume(
            rawKeyboardInputEvent(deviceID: deviceID, kind: .key(deadAcuteKey()))
        )
        let modifier = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(shiftKey()))
            ).first?.interpretedKey
        )
        let composed = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(aKey()))
            ).first?.interpretedKey
        )

        #expect(modifier.text == .none)
        #expect(composed.text.committedString == "á")
    }

    @Test
    func keymapChangeResetsActiveComposeSequence() throws {
        let interpreter = try interpreterWithFixtureKeymap(
            configuration: KeyboardInterpreterConfiguration(
                compose: .tableBuffer(composeTableText())
            )
        )
        let deviceID = keyboardDevice()

        _ = interpreter.consume(
            rawKeyboardInputEvent(deviceID: deviceID, kind: .key(deadAcuteKey()))
        )
        _ = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: deviceID,
                kind: .keymap(
                    try keymapPayload(
                        text: try fixtureKeymapText(),
                        keymapGeneration: 2
                    )
                )
            )
        )
        let key = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(aKey()))
            ).first?.interpretedKey
        )

        #expect(key.keysymName == "a")
        #expect(
            key.text
                == .committed(
                    KeyboardTextCommit(
                        string: "a",
                        source: .xkbKey,
                        resultKeysym: KeyboardKeysym(rawValue: 0x61),
                        resultKeysymName: "a"
                    )
                ))
    }

    @Test
    func unavailableComposeTableIsReportedOnceAndFallsBackToXKBText() throws {
        let interpreter = try KeyboardInterpreter(
            configuration: KeyboardInterpreterConfiguration(
                compose: .enabled(
                    locale: .identifier(try KeyboardComposeLocaleIdentifier("zz_ZZ.invalid"))
                )
            ),
            composeEnvironment: KeyboardComposeEnvironment()
        )
        let deviceID = keyboardDevice()
        let firstKeymapEvents = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: deviceID,
                kind: .keymap(try keymapPayload(text: try fixtureKeymapText()))
            )
        )

        #expect(firstKeymapEvents.count == 2)
        #expect(
            firstKeymapEvents.first?.kind
                == .keymap(
                    InterpretedKeyboardKeymap(
                        id: RawKeyboardKeymapID(
                            seatID: RawSeatID(rawValue: 1),
                            keyboardGeneration: 1,
                            keymapGeneration: 1
                        ),
                        format: .xkbV1,
                        size: UInt32(Array(try fixtureKeymapText().utf8).count + 1)
                    )
                ))
        #expect(
            firstKeymapEvents.last?.kind
                == unavailable(.composeTableUnavailable(locale: "zz_ZZ.invalid"))
        )

        let key = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(qKey()))
            ).first?.interpretedKey
        )
        let secondKeymapEvents = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: deviceID,
                kind: .keymap(
                    try keymapPayload(
                        text: try fixtureKeymapText(),
                        keymapGeneration: 2
                    )
                )
            )
        )

        #expect(key.text.committedString == "q")
        #expect(secondKeymapEvents.count == 1)
    }

    @Test
    func processComposeLocaleFallsBackToCWhenEnvironmentIsMissing() {
        #expect(
            KeyboardComposeLocale.processEnvironment.resolved(
                environment: KeyboardComposeEnvironment()
            ) == "C")
    }

    @Test
    func emptyComposeLocaleIdentifierIsRejected() {
        #expect(throws: KeyboardComposeLocaleError.emptyIdentifier) {
            try KeyboardComposeLocaleIdentifier("")
        }
    }

    @Test
    func whitespaceComposeLocaleIdentifierIsRejected() {
        #expect(throws: KeyboardComposeLocaleError.emptyIdentifier) {
            try KeyboardComposeLocaleIdentifier("   ")
        }
    }

    @Test
    func cannotCreateSymbolResolutionWithDisagreeingPrimarySymbol() {
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
        #expect(KeyboardSymbolResolution.resolved([]) == .single(.noSymbol))
    }

    @Test
    func multiSymbolKeyPreservesAllSymbolsAndSinglePrimaryRule() throws {
        let resolution = try KeyboardSymbolResolution(
            primary: KeyboardKeysym(rawValue: 0x61),
            all: [
                KeyboardKeysym(rawValue: 0x61),
                KeyboardKeysym(rawValue: 0x62),
            ]
        )

        #expect(resolution.primary == KeyboardKeysym(rawValue: 0x61))
        #expect(
            resolution.all == [
                KeyboardKeysym(rawValue: 0x61),
                KeyboardKeysym(rawValue: 0x62),
            ])
    }

    @Test
    func emptyComposeTableBufferIsReportedAndFallsBackToXKBText() throws {
        let interpreter = try KeyboardInterpreter(
            configuration: KeyboardInterpreterConfiguration(
                compose: .tableBuffer("")
            ),
            composeEnvironment: KeyboardComposeEnvironment()
        )
        let deviceID = keyboardDevice()
        let keymapEvents = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: deviceID,
                kind: .keymap(try keymapPayload(text: try fixtureKeymapText()))
            )
        )
        let key = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(qKey()))
            ).first?.interpretedKey
        )

        #expect(keymapEvents.last?.kind == unavailable(.emptyComposeTableBuffer))
        #expect(key.text.committedString == "q")
    }

    @Test
    func composeTableBufferContainingNULIsRejectedBeforeXKB() throws {
        let interpreter = try KeyboardInterpreter(
            configuration: KeyboardInterpreterConfiguration(
                compose: .tableBuffer("include \"en_US.UTF-8\"\0")
            ),
            composeEnvironment: KeyboardComposeEnvironment()
        )
        let deviceID = keyboardDevice()
        let keymapEvents = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: deviceID,
                kind: .keymap(try keymapPayload(text: try fixtureKeymapText()))
            )
        )
        let key = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .key(qKey()))
            ).first?.interpretedKey
        )

        #expect(keymapEvents.last?.kind == unavailable(.composeTableBufferContainsNUL))
        #expect(key.text.committedString == "q")
    }

    @Test
    func composeLocaleResolutionUsesProcessLocalePriority() throws {
        let locale = KeyboardComposeLocale.processEnvironment

        #expect(
            locale.resolved(
                environment: keyboardComposeEnvironment([
                    "LANG": "en_US.UTF-8",
                    "LC_CTYPE": "fr_FR.UTF-8",
                    "LC_ALL": "de_DE.UTF-8",
                ])
            )
                == "de_DE.UTF-8")
        #expect(
            locale.resolved(
                environment: keyboardComposeEnvironment([
                    "LANG": "en_US.UTF-8",
                    "LC_CTYPE": "fr_FR.UTF-8",
                ])
            ) == "fr_FR.UTF-8")
        #expect(
            locale.resolved(
                environment: keyboardComposeEnvironment([
                    "LANG": "en_US.UTF-8"
                ])
            ) == "en_US.UTF-8")
        #expect(
            KeyboardComposeLocale.identifier(
                try KeyboardComposeLocaleIdentifier(" sv_SE.UTF-8 ")
            ).resolved(environment: KeyboardComposeEnvironment()) == "sv_SE.UTF-8")
    }

    @Test
    func processComposeLocaleSkipsEmptyAndWhitespaceEnvironmentValues() {
        let locale = KeyboardComposeLocale.processEnvironment

        #expect(
            locale.resolved(
                environment: keyboardComposeEnvironment([
                    "LANG": "en_US.UTF-8",
                    "LC_CTYPE": "",
                    "LC_ALL": "   ",
                ])
            )
                == "en_US.UTF-8")
        #expect(
            locale.resolved(
                environment: keyboardComposeEnvironment([
                    "LANG": "\n",
                    "LC_CTYPE": "\t",
                    "LC_ALL": "   ",
                ])
            )
                == "C")
    }

    @Test
    func interpreterUsesProvidedComposeEnvironmentSnapshot() throws {
        let interpreter = try KeyboardInterpreter(
            configuration: KeyboardInterpreterConfiguration(
                compose: .enabled(locale: .processEnvironment)
            ),
            composeEnvironment: KeyboardComposeEnvironment(["LC_ALL": "zz_ZZ.invalid"])
        )
        let deviceID = keyboardDevice()
        let keymapEvents = interpreter.consume(
            rawKeyboardInputEvent(
                deviceID: deviceID,
                kind: .keymap(try keymapPayload(text: try fixtureKeymapText()))
            )
        )

        #expect(
            keymapEvents.last?.kind
                == unavailable(.composeTableUnavailable(locale: "zz_ZZ.invalid"))
        )
    }

    @Test
    func evdevKeycodeOverflowProducesInvalidKeycodeDiagnostic() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .key(qKey(evdevKeycode: UInt32.max))
                )
            ).first
        )

        #expect(event.kind == unavailable(.invalidKeycode(UInt32.max)))
    }

    @Test
    func modifierEventUpdatesStateAndReportsChangedComponents() throws {
        let interpreter = try interpreterWithFixtureKeymap()
        let deviceID = keyboardDevice()
        let shiftMask = try #require(
            KeyboardLayoutState(keymap: try keymapPayload(text: try fixtureKeymapText()))
                .modifierMask(named: "Shift"))
        let modifiers = RawKeyboardModifiers(
            serial: 9,
            depressed: shiftMask,
            latched: 0,
            locked: 0,
            group: 0
        )
        let modifierEvent = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(deviceID: deviceID, kind: .modifiers(modifiers))
            )
            .first
        )
        let interpretedModifiers = try #require(modifierEvent.interpretedModifiers)

        #expect(interpretedModifiers.serial == 9)
        #expect(interpretedModifiers.depressed == shiftMask)
        #expect(interpretedModifiers.changedComponents.contains(.modsDepressed))
        #expect(interpretedModifiers.changedComponents.contains(.modsEffective))

        let keyEvent = try #require(
            interpreter.consume(rawKeyboardInputEvent(deviceID: deviceID, kind: .key(qKey())))
                .first
        )
        #expect(keyEvent.interpretedKey?.keysymName == "Q")
        #expect(keyEvent.interpretedKey?.utf8 == "Q")
    }

    @Test
    func modifiersBeforeKeymapProduceMissingStateDiagnostic() throws {
        let interpreter = try testKeyboardInterpreter()
        let deviceID = keyboardDevice()
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .modifiers(
                        RawKeyboardModifiers(
                            serial: 1,
                            depressed: 0,
                            latched: 0,
                            locked: 0,
                            group: 0
                        )
                    )
                )
            ).first
        )

        #expect(event.kind == unavailable(.missingKeyboardState))
    }

    @Test
    func repeatInfoIsStoredAndEmittedWithoutSynthesizingEvents() throws {
        let interpreter = try testKeyboardInterpreter()
        let deviceID = keyboardDevice()
        let repeatInfo = try RawKeyboardRepeatInfo(rate: 30, delay: 400)
        let event = try #require(
            interpreter.consume(
                rawKeyboardInputEvent(
                    deviceID: deviceID,
                    kind: .repeatInfo(repeatInfo)
                )
            ).first
        )

        #expect(event.kind == .repeatInfo(InterpretedKeyboardRepeatInfo(repeatInfo)))
        #expect(interpreter.repeatInfo(for: deviceID) == repeatInfo)
    }

    @Test
    func zeroRepeatRateBecomesDisabled() throws {
        let repeatInfo = try RawKeyboardRepeatInfo(rate: 0, delay: 400)

        #expect(repeatInfo == .disabled)
    }

    @Test
    func negativeRepeatRateIsRejected() {
        #expect(throws: RawKeyboardRepeatInfoError.negativeRate(rate: -1, delay: 400)) {
            try RawKeyboardRepeatInfo(rate: -1, delay: 400)
        }
    }

    @Test
    func negativeRepeatDelayIsRejected() {
        #expect(throws: RawKeyboardRepeatInfoError.negativeDelay(rate: 30, delay: -1)) {
            try RawKeyboardRepeatInfo(rate: 30, delay: -1)
        }
    }

    @Test
    func interpretedPayloadsAreSendableValues() {
        requireSendable(InterpretedKeyboardEvent.self)
        requireSendable(InterpretedKeyboardEventKind.self)
        requireSendable(InterpretedKeyboardKey.self)
        requireSendable(InterpretedKeyboardKeyInterpretation.self)
        requireSendable(InterpretedKeyboardKeyState.self)
        requireSendable(KeyboardKeyRepeatCapability.self)
        requireSendable(KeyboardTextResult.self)
        requireSendable(KeyboardTextCommit.self)
        requireSendable(KeyboardTextSource.self)
        requireSendable(KeyboardComposeProgress.self)
        requireSendable(KeyboardComposeCancellation.self)
        requireSendable(KeyboardComposeLocaleIdentifier.self)
        requireSendable(KeyboardSymbolResolution.self)
        requireSendable(InterpretedKeyboardModifiers.self)
        requireSendable(KeyboardInterpretationUnavailable.self)
    }
}

private func keyboardComposeEnvironment(
    _ variables: [String: String]
) -> KeyboardComposeEnvironment {
    KeyboardComposeEnvironment(variables)
}
