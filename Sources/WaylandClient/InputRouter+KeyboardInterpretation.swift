import WaylandKeyboardInterpretation
import WaylandRaw

extension InputRouter {
    func route(_ event: WaylandKeyboardInterpretation.InterpretedKeyboardEvent) -> [InputEvent] {
        let routed = InputEvent(
            sequence: event.sequence,
            seatID: SeatID(rawValue: event.seatID.rawValue),
            windowID: interpretedWindowID(for: event),
            kind: .keyboard(.interpreted(convert(event.kind)))
        )

        return [routed]
    }

    func interpretedWindowID(
        for event: WaylandKeyboardInterpretation.InterpretedKeyboardEvent
    ) -> WindowID? {
        switch event.kind {
        case .key:
            focusedKeyboardWindow(for: event.seatID)
        case .keymap, .modifiers, .repeatInfo, .unavailable:
            nil
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
                    time: key.time,
                    rawKeycode: key.evdevKeycode,
                    xkbKeycode: key.xkbKeycode,
                    state: InterpretedKeyboardKeyState(rawValue: key.state.rawValue),
                    keysym: KeyboardKeysym(rawValue: key.keysym.rawValue),
                    keysymName: key.keysymName,
                    utf8: key.utf8,
                    repeats: key.repeats
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
            .repeatInfo(
                InterpretedKeyboardRepeatInfo(rate: repeatInfo.rate, delay: repeatInfo.delay)
            )
        case .unavailable(let unavailable):
            .unavailable(
                KeyboardInterpretationUnavailable(
                    reason: convert(unavailable.reason)
                )
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
}
