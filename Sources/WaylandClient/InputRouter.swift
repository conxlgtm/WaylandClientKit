import WaylandRaw

final class InputRouter {
    private var pointerFocusBySeat: [RawSeatID: RawObjectID] = [:]
    private var keyboardFocusBySeat: [RawSeatID: RawObjectID] = [:]
    private var windowsBySurface: [RawObjectID: WindowID] = [:]

    func register(windowID: WindowID, surfaceID: RawObjectID) {
        windowsBySurface[surfaceID] = windowID
    }

    func unregister(surfaceID: RawObjectID) {
        windowsBySurface.removeValue(forKey: surfaceID)
        pointerFocusBySeat = pointerFocusBySeat.filter { $0.value != surfaceID }
        keyboardFocusBySeat = keyboardFocusBySeat.filter { $0.value != surfaceID }
    }

    func route(_ event: RawInputEvent) -> [InputEvent] {
        guard let routed = routeOne(event) else {
            return []
        }

        return [routed]
    }

    private func routeOne(_ event: RawInputEvent) -> InputEvent? {
        switch event.kind {
        case .seat(let snapshot):
            return routedEvent(
                event,
                windowID: nil,
                kind: .seat(.changed(convert(snapshot)))
            )
        case .seatRemoved:
            pointerFocusBySeat[event.seatID] = nil
            keyboardFocusBySeat[event.seatID] = nil
            return routedEvent(event, windowID: nil, kind: .seat(.removed))
        case .pointer(let pointerEvent):
            return routePointer(event, pointerEvent)
        case .keyboard(let keyboardEvent):
            return routeKeyboard(event, keyboardEvent)
        case .touch:
            return nil
        }
    }

    private func routePointer(
        _ rawEvent: RawInputEvent,
        _ pointerEvent: RawPointerEvent
    ) -> InputEvent {
        switch pointerEvent {
        case .enter(let enter):
            if let surfaceID = enter.surfaceID {
                pointerFocusBySeat[rawEvent.seatID] = surfaceID
            }
            return routedEvent(
                rawEvent,
                windowID: windowID(for: enter.surfaceID),
                kind: .pointer(
                    .entered(
                        PointerLocation(x: enter.x.doubleValue, y: enter.y.doubleValue),
                        serial: enter.serial
                    )
                )
            )
        case .leave(let leave):
            let windowID = windowID(for: leave.surfaceID)
            clearPointerFocus(seatID: rawEvent.seatID, surfaceID: leave.surfaceID)
            return routedEvent(
                rawEvent,
                windowID: windowID,
                kind: .pointer(.left(serial: leave.serial))
            )
        case .motion(let motion):
            return routedEvent(
                rawEvent,
                windowID: focusedPointerWindow(for: rawEvent.seatID),
                kind: .pointer(
                    .moved(
                        PointerLocation(x: motion.x.doubleValue, y: motion.y.doubleValue),
                        time: motion.time
                    )
                )
            )
        case .button(let button):
            return routedEvent(
                rawEvent,
                windowID: focusedPointerWindow(for: rawEvent.seatID),
                kind: .pointer(
                    .button(
                        PointerButtonEvent(
                            serial: button.serial,
                            time: button.time,
                            button: button.button,
                            state: ButtonState(rawValue: button.state.rawValue)
                        )
                    )
                )
            )
        case .axis(let axis):
            return routedEvent(
                rawEvent,
                windowID: focusedPointerWindow(for: rawEvent.seatID),
                kind: .pointer(.axis(convert(axis)))
            )
        }
    }

    private func routeKeyboard(
        _ rawEvent: RawInputEvent,
        _ keyboardEvent: RawKeyboardEvent
    ) -> InputEvent {
        switch keyboardEvent {
        case .keymap(let keymap):
            return routeKeyboardKeymap(rawEvent, keymap)
        case .enter(let enter):
            return routeKeyboardEnter(rawEvent, enter)
        case .leave(let leave):
            return routeKeyboardLeave(rawEvent, leave)
        case .key(let key):
            return routeKeyboardKey(rawEvent, key)
        case .modifiers(let modifiers):
            return routeKeyboardModifiers(rawEvent, modifiers)
        case .repeatInfo(let repeatInfo):
            return routeKeyboardRepeatInfo(rawEvent, repeatInfo)
        }
    }
}

extension InputRouter {
    func routeKeyboardKeymap(
        _ rawEvent: RawInputEvent,
        _ keymap: RawKeyboardKeymapPayload
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            windowID: nil,
            kind: .keyboard(
                .keymapChanged(
                    KeyboardKeymapInfo(
                        format: KeyboardKeymapFormat(rawValue: keymap.format.rawValue),
                        size: keymap.size
                    )
                )
            )
        )
    }

    func routeKeyboardEnter(
        _ rawEvent: RawInputEvent,
        _ enter: RawKeyboardEnter
    ) -> InputEvent {
        if let surfaceID = enter.surfaceID {
            keyboardFocusBySeat[rawEvent.seatID] = surfaceID
        }

        return routedEvent(
            rawEvent,
            windowID: windowID(for: enter.surfaceID),
            kind: .keyboard(.entered(serial: enter.serial, pressedKeys: enter.pressedKeys))
        )
    }

    func routeKeyboardLeave(
        _ rawEvent: RawInputEvent,
        _ leave: RawKeyboardLeave
    ) -> InputEvent {
        let windowID = windowID(for: leave.surfaceID)
        clearKeyboardFocus(seatID: rawEvent.seatID, surfaceID: leave.surfaceID)
        return routedEvent(
            rawEvent,
            windowID: windowID,
            kind: .keyboard(.left(serial: leave.serial))
        )
    }

    func routeKeyboardKey(
        _ rawEvent: RawInputEvent,
        _ key: RawKeyboardKey
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            windowID: focusedKeyboardWindow(for: rawEvent.seatID),
            kind: .keyboard(
                .key(
                    KeyboardKeyEvent(
                        serial: key.serial,
                        time: key.time,
                        rawKeycode: key.evdevKeycode,
                        state: KeyState(rawValue: key.state.rawValue)
                    )
                )
            )
        )
    }

    func routeKeyboardModifiers(
        _ rawEvent: RawInputEvent,
        _ modifiers: RawKeyboardModifiers
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            windowID: nil,
            kind: .keyboard(
                .modifiers(
                    KeyboardModifiers(
                        serial: modifiers.serial,
                        depressed: modifiers.depressed,
                        latched: modifiers.latched,
                        locked: modifiers.locked,
                        group: modifiers.group
                    )
                )
            )
        )
    }

    func routeKeyboardRepeatInfo(
        _ rawEvent: RawInputEvent,
        _ repeatInfo: RawKeyboardRepeatInfo
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            windowID: nil,
            kind: .keyboard(
                .repeatInfo(KeyboardRepeatInfo(rate: repeatInfo.rate, delay: repeatInfo.delay))
            )
        )
    }

    func routedEvent(
        _ rawEvent: RawInputEvent,
        windowID: WindowID?,
        kind: InputEventKind
    ) -> InputEvent {
        InputEvent(
            sequence: rawEvent.sequence,
            seatID: SeatID(rawValue: rawEvent.seatID.rawValue),
            windowID: windowID,
            kind: kind
        )
    }

    func convert(_ snapshot: RawSeatEventSnapshot) -> SeatStateSnapshot {
        SeatStateSnapshot(
            advertisedCapabilities: snapshot.advertisedCapabilities,
            activeCapabilities: snapshot.activeCapabilities,
            name: snapshot.name
        )
    }

    func convert(_ axis: RawPointerAxisEvent) -> PointerAxisEvent {
        switch axis {
        case .axis(let time, let rawAxis, let value):
            .axis(
                time: time,
                axis: PointerAxis(rawValue: rawAxis.rawValue),
                value: value.doubleValue
            )
        case .source(let source):
            .source(PointerAxisSource(rawValue: source.rawValue))
        case .stop(let time, let axis):
            .stop(time: time, axis: PointerAxis(rawValue: axis.rawValue))
        case .discrete(let axis, let value):
            .discrete(axis: PointerAxis(rawValue: axis.rawValue), value: value)
        case .value120(let axis, let value120):
            .value120(axis: PointerAxis(rawValue: axis.rawValue), value120: value120)
        case .relativeDirection(let axis, let direction):
            .relativeDirection(
                axis: PointerAxis(rawValue: axis.rawValue),
                direction: PointerAxisRelativeDirection(rawValue: direction.rawValue)
            )
        case .frame:
            .frame
        }
    }

    func windowID(for surfaceID: RawObjectID?) -> WindowID? {
        guard let surfaceID else {
            return nil
        }

        return windowsBySurface[surfaceID]
    }

    func focusedPointerWindow(for seatID: RawSeatID) -> WindowID? {
        windowID(for: pointerFocusBySeat[seatID])
    }

    func focusedKeyboardWindow(for seatID: RawSeatID) -> WindowID? {
        windowID(for: keyboardFocusBySeat[seatID])
    }

    func clearPointerFocus(seatID: RawSeatID, surfaceID: RawObjectID?) {
        guard let surfaceID, pointerFocusBySeat[seatID] == surfaceID else {
            return
        }

        pointerFocusBySeat[seatID] = nil
    }

    func clearKeyboardFocus(seatID: RawSeatID, surfaceID: RawObjectID?) {
        guard let surfaceID, keyboardFocusBySeat[seatID] == surfaceID else {
            return
        }

        keyboardFocusBySeat[seatID] = nil
    }
}
