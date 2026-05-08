import WaylandRaw

enum KeyboardInterpreterKeymapStorage {
    case missing
    case noKeymap(RawKeyboardKeymapID)
    case valid(KeyboardLayoutState)
    case unavailable(
        keymapID: RawKeyboardKeymapID?,
        reason: KeyboardInterpretationUnavailableReason
    )

    var validLayout: KeyboardLayoutState? {
        switch self {
        case .valid(let layout):
            layout
        case .missing, .noKeymap, .unavailable:
            nil
        }
    }

    var validKeymapID: RawKeyboardKeymapID? {
        switch self {
        case .valid(let layout):
            layout.id
        case .missing, .noKeymap, .unavailable:
            nil
        }
    }

    var snapshot: KeyboardInterpreterKeymapState {
        switch self {
        case .missing:
            .missing
        case .noKeymap(let id):
            .noKeymap(id)
        case .valid(let layout):
            .valid(layout.id)
        case .unavailable(let keymapID, let reason):
            .unavailable(keymapID: keymapID, reason: reason)
        }
    }

    var failureReason: KeyboardInterpretationUnavailableReason? {
        switch self {
        case .noKeymap:
            .noKeymap
        case .unavailable(_, let reason):
            reason
        case .missing, .valid:
            nil
        }
    }
}

struct KeyboardInterpreterDeviceState {
    var keymap = KeyboardInterpreterKeymapStorage.missing
    var repeatInfo: RawKeyboardRepeatInfo?
}
