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
                    time: key.time,
                    rawKeycode: key.evdevKeycode,
                    xkbKeycode: key.xkbKeycode,
                    keysym: KeyboardKeysym(rawValue: key.keysym.rawValue),
                    interpretation: convert(key.interpretation)
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
