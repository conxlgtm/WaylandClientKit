import WaylandKeyboardInterpretation
import WaylandRaw

extension InputRouter {
    func route(_ event: WaylandKeyboardInterpretation.InterpretedKeyboardEvent) -> [InputEvent] {
        let routed = InputEvent(
            sequence: event.sequence,
            seatID: SeatID(rawValue: event.seatID.rawValue),
            target: interpretedTarget(for: event),
            kind: .keyboard(.interpreted(convert(event.kind)))
        )

        return [routed]
    }

    func interpretedTarget(
        for event: WaylandKeyboardInterpretation.InterpretedKeyboardEvent
    ) -> InputEventTarget {
        switch event.kind {
        case .key:
            target(forFocusedSurface: focusedKeyboardSurface(for: event.seatID))
        case .keymap, .modifiers, .repeatInfo, .unavailable:
            .display
        }
    }

    func convert(
        _ event: WaylandKeyboardInterpretation.InterpretedKeyboardEventKind
    ) -> InterpretedKeyboardEvent {
        switch event {
        case .keymap(let keymap):
            .keymap(
                InterpretedKeyboardKeymapInfo(
                    format: KeyboardKeymapFormat(rawValue: keymap.format.rawValue),
                    size: keymap.size
                )
            )
        case .key(let key):
            .key(
                InterpretedKeyboardKeyEvent(
                    serial: InputSerial(rawValue: key.serial),
                    time: WaylandTimestampMilliseconds(rawValue: key.time),
                    rawKeycode: EvdevKeycode(rawValue: key.evdevKeycode),
                    xkbKeycode: XKBKeycode(rawValue: key.xkbKeycode),
                    symbolResolution: convert(key.symbolResolution),
                    interpretation: convert(key.interpretation),
                    text: convert(key.text)
                )
            )
        case .modifiers(let modifiers):
            .modifiers(
                InterpretedKeyboardModifiers(
                    serial: InputSerial(rawValue: modifiers.serial),
                    depressed: modifiers.depressed,
                    latched: modifiers.latched,
                    locked: modifiers.locked,
                    group: modifiers.group,
                    changedComponents: KeyboardModifierStateComponents(
                        rawValue: modifiers.changedComponents.rawValue
                    )
                )
            )
        case .repeatInfo(let repeatInfo):
            .repeatInfo(convert(repeatInfo))
        case .unavailable(let unavailable):
            .unavailable(
                KeyboardInterpretationUnavailable(
                    reason: convert(unavailable.reason)
                )
            )
        }
    }

    func convert(
        _ resolution: WaylandKeyboardInterpretation.KeyboardSymbolResolution
    ) -> KeyboardSymbolResolution {
        .resolved(
            resolution.all.map { keysym in
                KeyboardKeysym(rawValue: keysym.rawValue)
            }
        )
    }

    func convert(
        _ interpretation: WaylandKeyboardInterpretation.InterpretedKeyboardKeyInterpretation
    ) -> InterpretedKeyboardKeyInterpretation {
        switch interpretation {
        case .released(let keysymName):
            .released(keysymName: keysymName)
        case .pressed(let keysymName, let utf8, let repeatCapability):
            .pressed(
                keysymName: keysymName,
                utf8: utf8,
                repeatCapability: convert(repeatCapability)
            )
        case .repeated(let keysymName, let utf8):
            .repeated(keysymName: keysymName, utf8: utf8)
        case .unknown(let state, let keysymName):
            .unknown(
                state: InterpretedKeyboardKeyState(rawValue: state.rawValue),
                keysymName: keysymName
            )
        }
    }

    func convert(
        _ repeatCapability: WaylandKeyboardInterpretation.KeyboardKeyRepeatCapability
    ) -> KeyboardKeyRepeatCapability {
        switch repeatCapability {
        case .nonRepeating:
            .nonRepeating
        case .repeating:
            .repeating
        }
    }

    func convert(
        _ repeatInfo: WaylandKeyboardInterpretation.InterpretedKeyboardRepeatInfo
    ) -> KeyboardRepeatPolicy {
        switch repeatInfo {
        case .disabled:
            .disabled
        case .enabled(let rate, let delay):
            .enabled(
                rate: KeyboardRepeatRate(unchecked: rate.rawValue),
                delay: KeyboardRepeatDelay(unchecked: delay.rawValue)
            )
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func convert(
        _ reason: WaylandKeyboardInterpretation.KeyboardInterpretationUnavailableReason
    ) -> KeyboardInterpretationUnavailableReason {
        switch reason {
        case .missingDeviceID:
            .missingDeviceID
        case .noKeymap:
            .noKeymap
        case .unsupportedKeymapFormat(let format):
            .unsupportedKeymapFormat(format)
        case .emptyKeymap:
            .emptyKeymap
        case .invalidKeymap:
            .invalidKeymap
        case .keymapReadFailed(let error):
            .keymapReadFailed(convert(error))
        case .composeTableUnavailable(let locale):
            .composeTableUnavailable(locale: locale)
        case .composeStateCreationFailed:
            .composeStateCreationFailed
        case .missingKeymap:
            .missingKeymap
        case .missingKeyboardState:
            .missingKeyboardState
        case .invalidKeycode(let keycode):
            .invalidKeycode(keycode)
        case .nonKeyboardInputDevice:
            .nonKeyboardInputDevice
        case .mismatchedKeyboardSeat(let expected, let actual):
            .mismatchedKeyboardSeat(
                expected: SeatID(rawValue: expected.rawValue),
                actual: SeatID(rawValue: actual.rawValue)
            )
        case .mismatchedKeyboardDevice:
            .mismatchedKeyboardDevice
        }
    }

    func convert(
        _ text: WaylandKeyboardInterpretation.KeyboardTextResult
    ) -> KeyboardTextResult {
        switch text {
        case .none:
            .none
        case .composing(let progress):
            .composing(
                KeyboardComposeProgress(
                    startedBy: progress.startedBy.map { keysym in
                        KeyboardKeysym(rawValue: keysym.rawValue)
                    },
                    startedByName: progress.startedByName
                )
            )
        case .committed(let commit):
            .committed(convert(commit))
        case .cancelled(let cancellation):
            .cancelled(
                KeyboardComposeCancellation(
                    cancellingKeysym: cancellation.cancellingKeysym.map { keysym in
                        KeyboardKeysym(rawValue: keysym.rawValue)
                    },
                    cancellingKeysymName: cancellation.cancellingKeysymName,
                    fallbackCommit: cancellation.fallbackCommit.map(convert)
                )
            )
        }
    }

    func convert(
        _ commit: WaylandKeyboardInterpretation.KeyboardTextCommit
    ) -> KeyboardTextCommit {
        KeyboardTextCommit(
            string: commit.string,
            source: convert(commit.source),
            resultKeysym: commit.resultKeysym.map { KeyboardKeysym(rawValue: $0.rawValue) },
            resultKeysymName: commit.resultKeysymName
        )
    }

    func convert(
        _ source: WaylandKeyboardInterpretation.KeyboardTextSource
    ) -> KeyboardTextSource {
        switch source {
        case .xkbKey:
            .xkbKey
        case .compose:
            .compose
        case .composeCancellationFallback:
            .composeCancellationFallback
        }
    }
}
