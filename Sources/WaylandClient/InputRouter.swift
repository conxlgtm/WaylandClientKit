import WaylandRaw

final class InputRouter {
    var deviceGraph = InputDeviceGraph()
    private var windowsBySurface: [RawObjectID: WindowID] = [:]

    func register(windowID: WindowID, surfaceID: RawObjectID) {
        windowsBySurface[surfaceID] = windowID
    }

    func unregister(surfaceID: RawObjectID) {
        windowsBySurface.removeValue(forKey: surfaceID)
        removeSurfaceFromDeviceGraph(surfaceID)
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
            applySeatSnapshot(event, snapshot)
            return routedEvent(
                event,
                windowID: nil,
                kind: .seat(.changed(convert(snapshot)))
            )
        case .seatRemoved:
            deviceGraph.removeSeat(event.seatID)
            return routedEvent(event, windowID: nil, kind: .seat(.removed))
        case .diagnostic(let diagnostic):
            return routedEvent(
                event,
                windowID: nil,
                kind: .diagnostic(convert(diagnostic))
            )
        case .pointer(let pointerEvent):
            guard acceptPointerDeviceEvent(event) else {
                return nil
            }
            return routePointer(event, pointerEvent)
        case .keyboard(let keyboardEvent):
            guard acceptKeyboardDeviceEvent(event) else {
                return nil
            }
            return routeKeyboard(event, keyboardEvent)
        case .touch(let touchEvent):
            guard acceptTouchDeviceEvent(event) else {
                return nil
            }
            return routeTouch(event, touchEvent)
        }
    }

    private func routePointer(
        _ rawEvent: RawInputEvent,
        _ pointerEvent: RawPointerEvent
    ) -> InputEvent {
        switch pointerEvent {
        case .enter(let enter):
            if let surfaceID = enter.surfaceID {
                setPointerFocus(seatID: rawEvent.seatID, surfaceID: surfaceID)
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
        _ keyboardEvent: WaylandRaw.RawKeyboardEvent
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

    private func routeTouch(
        _ rawEvent: RawInputEvent,
        _ touchEvent: RawTouchEvent
    ) -> InputEvent {
        switch touchEvent {
        case .down(let down):
            return routeTouchDown(rawEvent, down)
        case .up(let up):
            return routeTouchUp(rawEvent, up)
        case .motion(let motion):
            return routeTouchMotion(rawEvent, motion)
        case .frame:
            return routedEvent(rawEvent, windowID: nil, kind: .touch(.frame))
        case .cancel:
            clearTouchFocuses(seatID: rawEvent.seatID)
            return routedEvent(rawEvent, windowID: nil, kind: .touch(.cancel))
        case .shape(let shape):
            return routeTouchShape(rawEvent, shape)
        case .orientation(let orientation):
            return routeTouchOrientation(rawEvent, orientation)
        }
    }
}

extension InputRouter {
    func routeTouchDown(
        _ rawEvent: RawInputEvent,
        _ down: RawTouchDown
    ) -> InputEvent {
        if let surfaceID = down.surfaceID {
            setTouchFocus(seatID: rawEvent.seatID, touchID: down.id, surfaceID: surfaceID)
        }
        return routedEvent(
            rawEvent,
            windowID: windowID(for: down.surfaceID),
            kind: .touch(
                .down(
                    TouchDownEvent(
                        serial: down.serial,
                        time: down.time,
                        id: down.id,
                        location: PointerLocation(
                            x: down.x.doubleValue,
                            y: down.y.doubleValue
                        )
                    )
                )
            )
        )
    }

    func routeTouchUp(
        _ rawEvent: RawInputEvent,
        _ up: RawTouchUp
    ) -> InputEvent {
        let windowID = focusedTouchWindow(for: rawEvent.seatID, touchID: up.id)
        clearTouchFocus(seatID: rawEvent.seatID, touchID: up.id)
        return routedEvent(
            rawEvent,
            windowID: windowID,
            kind: .touch(.up(TouchUpEvent(serial: up.serial, time: up.time, id: up.id)))
        )
    }

    func routeTouchMotion(
        _ rawEvent: RawInputEvent,
        _ motion: RawTouchMotion
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            windowID: focusedTouchWindow(for: rawEvent.seatID, touchID: motion.id),
            kind: .touch(
                .motion(
                    TouchMotionEvent(
                        time: motion.time,
                        id: motion.id,
                        location: PointerLocation(
                            x: motion.x.doubleValue,
                            y: motion.y.doubleValue
                        )
                    )
                )
            )
        )
    }

    func routeTouchShape(
        _ rawEvent: RawInputEvent,
        _ shape: RawTouchShape
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            windowID: focusedTouchWindow(for: rawEvent.seatID, touchID: shape.id),
            kind: .touch(
                .shape(
                    TouchShapeEvent(
                        id: shape.id,
                        major: shape.major.doubleValue,
                        minor: shape.minor.doubleValue
                    )
                )
            )
        )
    }

    func routeTouchOrientation(
        _ rawEvent: RawInputEvent,
        _ orientation: RawTouchOrientation
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            windowID: focusedTouchWindow(for: rawEvent.seatID, touchID: orientation.id),
            kind: .touch(
                .orientation(
                    TouchOrientationEvent(
                        id: orientation.id,
                        orientation: orientation.orientation.doubleValue
                    )
                )
            )
        )
    }

    func routeKeyboardKeymap(
        _ rawEvent: RawInputEvent,
        _ keymap: RawKeyboardKeymapPayload
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            windowID: nil,
            kind: .keyboard(
                .raw(
                    .keymapChanged(
                        KeyboardKeymapInfo(
                            format: KeyboardKeymapFormat(rawValue: keymap.format.rawValue),
                            size: keymap.size
                        )
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
            setKeyboardFocus(seatID: rawEvent.seatID, surfaceID: surfaceID)
        }

        return routedEvent(
            rawEvent,
            windowID: windowID(for: enter.surfaceID),
            kind: .keyboard(.raw(.entered(serial: enter.serial, pressedKeys: enter.pressedKeys)))
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
            kind: .keyboard(.raw(.left(serial: leave.serial)))
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
                .raw(
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
                .raw(
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
                .raw(
                    .repeatInfo(
                        KeyboardRepeatInfo(rate: repeatInfo.rate, delay: repeatInfo.delay)
                    )
                )
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
            advertisedCapabilities: SeatCapabilities(
                rawValue: snapshot.advertisedCapabilities.rawValue
            ),
            activeCapabilities: SeatCapabilities(rawValue: snapshot.activeCapabilities.rawValue),
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
}
