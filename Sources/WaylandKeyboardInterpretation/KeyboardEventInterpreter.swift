import WaylandRaw

public final class KeyboardEventInterpreter {
    private var layout: KeyboardLayoutState?
    private var keyboardDeviceID: RawInputDeviceID?
    private let threadAffinity = ThreadAffinity()

    public init() {
        // Starts without a keymap; key events are ignored until one arrives.
    }

    public var currentKeymapID: RawKeyboardKeymapID? {
        threadAffinity.preconditionIsOwnerThread()
        return layout?.id
    }

    public var currentKeyboardDeviceID: RawInputDeviceID? {
        threadAffinity.preconditionIsOwnerThread()
        return keyboardDeviceID
    }

    public func handle(_ event: RawInputEvent) throws(KeyboardInterpretationError)
        -> InterpretedKeyEvent?
    {
        threadAffinity.preconditionIsOwnerThread()

        switch event.kind {
        case .keyboard(let keyboardEvent):
            try bindKeyboardDevice(event.deviceID)
            return try handleKeyboardEvent(keyboardEvent)
        case .seat(let snapshot):
            if !snapshot.activeCapabilities.contains(.keyboard) {
                resetIfMatchingSeat(event.seatID)
            }
            return nil
        case .seatRemoved:
            resetIfMatchingSeat(event.seatID)
            return nil
        case .pointer, .touch:
            return nil
        }
    }

    public func handle(_ event: RawKeyboardEvent) throws(KeyboardInterpretationError)
        -> InterpretedKeyEvent?
    {
        threadAffinity.preconditionIsOwnerThread()

        return try handleKeyboardEvent(event)
    }

    public func reset() {
        threadAffinity.preconditionIsOwnerThread()
        resetState()
    }

    deinit {
        threadAffinity.preconditionIsOwnerThread()
    }

    private func handleKeyboardEvent(_ event: RawKeyboardEvent)
        throws(KeyboardInterpretationError) -> InterpretedKeyEvent?
    {
        switch event {
        case .keymap(let keymap):
            try updateKeymap(keymap)
            return nil
        case .modifiers(let modifiers):
            layout?.applyModifiers(modifiers)
            return nil
        case .key(let key):
            return layout?.interpret(key)
        case .enter, .leave, .repeatInfo:
            return nil
        }
    }

    private func resetState() {
        layout = nil
        keyboardDeviceID = nil
    }

    private func resetIfMatchingSeat(_ seatID: RawSeatID) {
        if keyboardDeviceID?.seatID == seatID || layout?.id.seatID == seatID {
            resetState()
        }
    }

    private func bindKeyboardDevice(_ eventDeviceID: RawInputDeviceID?)
        throws(KeyboardInterpretationError)
    {
        guard let eventDeviceID else {
            return
        }

        guard eventDeviceID.kind == .keyboard else {
            throw .nonKeyboardInputDevice(eventDeviceID)
        }

        try validateKeyboardDevice(eventDeviceID)
        keyboardDeviceID = eventDeviceID
    }

    private func updateKeymap(_ keymap: RawKeyboardKeymapPayload)
        throws(KeyboardInterpretationError)
    {
        try validateKeyboardDevice(
            RawInputDeviceID(
                seatID: keymap.id.seatID,
                kind: .keyboard,
                generation: keymap.id.keyboardGeneration
            )
        )

        if keymap.format == .noKeymap {
            layout = nil
            return
        }

        layout = try KeyboardLayoutState(keymap: keymap)
    }

    private func validateKeyboardDevice(_ deviceID: RawInputDeviceID)
        throws(KeyboardInterpretationError)
    {
        guard let keyboardDeviceID, keyboardDeviceID != deviceID else {
            return
        }

        throw .mismatchedKeyboardDevice(expected: keyboardDeviceID, actual: deviceID)
    }
}
