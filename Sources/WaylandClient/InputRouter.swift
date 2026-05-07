import WaylandRaw

struct AcceptedRawInputEvent {
    let raw: RawInputEvent
}

enum InputRouterError: Error, Equatable, Sendable {
    case unknownParentSurface(RawObjectID)
}

private struct InputSurfaceBinding: Equatable {
    let windowID: WindowID
}

final class InputRouter {
    var deviceGraph = InputDeviceGraph()
    private var surfaces: [RawObjectID: InputSurfaceBinding] = [:]

    func register(windowID: WindowID, surfaceID: RawObjectID) {
        surfaces[surfaceID] = InputSurfaceBinding(windowID: windowID)
    }

    func registerPopup(parentSurfaceID: RawObjectID, surfaceID: RawObjectID) throws {
        guard let parent = surfaces[parentSurfaceID] else {
            throw InputRouterError.unknownParentSurface(parentSurfaceID)
        }

        surfaces[surfaceID] = InputSurfaceBinding(windowID: parent.windowID)
    }

    func unregister(surfaceID: RawObjectID) {
        surfaces.removeValue(forKey: surfaceID)
        removeSurfaceFromDeviceGraph(surfaceID)
    }

    func route(_ event: RawInputEvent) -> [InputEvent] {
        guard let acceptedEvent = acceptRawInputEvent(event) else {
            return []
        }

        return route(acceptedEvent)
    }

    func acceptRawInputEvent(_ event: RawInputEvent) -> AcceptedRawInputEvent? {
        let isAccepted: Bool
        switch event.kind {
        case .pointer:
            isAccepted = acceptPointerDeviceEvent(event)
        case .keyboard:
            isAccepted = acceptKeyboardDeviceEvent(event)
        case .touch:
            isAccepted = acceptTouchDeviceEvent(event)
        case .seat, .seatRemoved, .diagnostic:
            isAccepted = true
        }

        guard isAccepted else {
            return nil
        }

        return AcceptedRawInputEvent(raw: event)
    }

    func route(_ event: AcceptedRawInputEvent) -> [InputEvent] {
        guard let routed = routeOne(event.raw) else {
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
                target: .display,
                kind: .seat(.changed(convert(snapshot)))
            )
        case .seatRemoved:
            deviceGraph.removeSeat(event.seatID)
            return routedEvent(event, target: .display, kind: .seat(.removed))
        case .diagnostic(let diagnostic):
            return routedEvent(
                event,
                target: .display,
                kind: .diagnostic(convert(diagnostic))
            )
        case .pointer(let pointerEvent):
            return routePointer(event, pointerEvent)
        case .keyboard(let keyboardEvent):
            return routeKeyboard(event, keyboardEvent)
        case .touch(let touchEvent):
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
                target: target(for: enter.surfaceID),
                kind: .pointer(
                    .entered(
                        PointerLocation(x: enter.x.doubleValue, y: enter.y.doubleValue),
                        serial: InputSerial(rawValue: enter.serial)
                    )
                )
            )
        case .leave(let leave):
            let target = target(for: leave.surfaceID)
            clearPointerFocus(seatID: rawEvent.seatID, surfaceID: leave.surfaceID)
            return routedEvent(
                rawEvent,
                target: target,
                kind: .pointer(.left(serial: InputSerial(rawValue: leave.serial)))
            )
        case .motion(let motion):
            return routedEvent(
                rawEvent,
                target: target(forFocusedSurface: focusedPointerSurface(for: rawEvent.seatID)),
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
                target: target(forFocusedSurface: focusedPointerSurface(for: rawEvent.seatID)),
                kind: .pointer(
                    .button(
                        PointerButtonEvent(
                            serial: InputSerial(rawValue: button.serial),
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
                target: target(forFocusedSurface: focusedPointerSurface(for: rawEvent.seatID)),
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
            return routedEvent(rawEvent, target: .display, kind: .touch(.frame))
        case .cancel:
            clearTouchFocuses(seatID: rawEvent.seatID)
            return routedEvent(rawEvent, target: .display, kind: .touch(.cancel))
        case .shape(let shape):
            return routeTouchShape(rawEvent, shape)
        case .orientation(let orientation):
            return routeTouchOrientation(rawEvent, orientation)
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
            target: .display,
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
            target: target(for: enter.surfaceID),
            kind: .keyboard(
                .raw(
                    .entered(
                        serial: InputSerial(rawValue: enter.serial),
                        pressedKeys: enter.pressedKeys
                    )
                )
            )
        )
    }

    func routeKeyboardLeave(
        _ rawEvent: RawInputEvent,
        _ leave: RawKeyboardLeave
    ) -> InputEvent {
        let target = target(for: leave.surfaceID)
        clearKeyboardFocus(seatID: rawEvent.seatID, surfaceID: leave.surfaceID)
        return routedEvent(
            rawEvent,
            target: target,
            kind: .keyboard(.raw(.left(serial: InputSerial(rawValue: leave.serial))))
        )
    }

    func routeKeyboardKey(
        _ rawEvent: RawInputEvent,
        _ key: RawKeyboardKey
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            target: target(forFocusedSurface: focusedKeyboardSurface(for: rawEvent.seatID)),
            kind: .keyboard(
                .raw(
                    .key(
                        KeyboardKeyEvent(
                            serial: InputSerial(rawValue: key.serial),
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
            target: .display,
            kind: .keyboard(
                .raw(
                    .modifiers(
                        KeyboardModifiers(
                            serial: InputSerial(rawValue: modifiers.serial),
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
            target: .display,
            kind: .keyboard(
                .raw(
                    .repeatInfo(
                        KeyboardRepeatPolicy(repeatInfo)
                    )
                )
            )
        )
    }

    func routedEvent(
        _ rawEvent: RawInputEvent,
        target: InputEventTarget,
        kind: InputEventKind
    ) -> InputEvent {
        InputEvent(
            sequence: rawEvent.sequence,
            seatID: SeatID(rawValue: rawEvent.seatID.rawValue),
            target: target,
            kind: kind
        )
    }

    func target(for surfaceID: RawObjectID?) -> InputEventTarget {
        guard let surfaceID else {
            return .unmanagedSurface
        }
        guard let windowID = windowID(for: surfaceID) else {
            return .unmanagedSurface
        }

        return .window(windowID)
    }

    func target(forFocusedSurface surfaceID: RawObjectID?) -> InputEventTarget {
        guard let surfaceID else {
            return .focusless
        }

        return target(for: surfaceID)
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

        return surfaces[surfaceID]?.windowID
    }
}
