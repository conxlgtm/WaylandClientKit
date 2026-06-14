import WaylandRaw

struct AcceptedRawInputEvent {
    let raw: RawInputEvent
}

enum InputRouterError: Error, Equatable, Sendable {
    case unknownParentSurface(RawObjectID)
}

private struct InputSurfaceBinding: Equatable {
    let target: SurfaceTarget

    var windowID: WindowID {
        target.windowID
    }
}

struct ReportedUnknownInputProtocolValue: Hashable {
    let seatID: SeatID
    let field: UnknownInputProtocolValueField
    let rawValue: UInt32
}

final class InputRouter {
    var deviceGraph = InputDeviceGraph()
    private var surfaces: [RawObjectID: InputSurfaceBinding] = [:]
    var tabletToolFocusByObjectID: [RawObjectID: RawObjectID] = [:]
    var tabletPadFocusByObjectID: [RawObjectID: RawObjectID] = [:]
    var reportedUnknownProtocolValues: Set<ReportedUnknownInputProtocolValue> = []

    func register(windowID: WindowID, surfaceID: RawObjectID) {
        surfaces[surfaceID] = InputSurfaceBinding(target: .window(windowID))
    }

    func registerPopup(
        popupID: PopupID,
        parentSurfaceID: RawObjectID,
        surfaceID: RawObjectID
    ) throws {
        guard let parent = surfaces[parentSurfaceID] else {
            throw InputRouterError.unknownParentSurface(parentSurfaceID)
        }

        surfaces[surfaceID] = InputSurfaceBinding(
            target: .popup(
                PopupSurfaceIdentity(popupID),
                parentWindowID: parent.windowID
            )
        )
    }

    func unregister(surfaceID: RawObjectID) {
        surfaces.removeValue(forKey: surfaceID)
        removeSurfaceFromDeviceGraph(surfaceID)
        removeTabletFocuses(matching: surfaceID)
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
        case .tablet:
            isAccepted = true
        case .seat, .seatRemoved, .diagnostic:
            isAccepted = true
        }

        guard isAccepted else {
            return nil
        }

        return AcceptedRawInputEvent(raw: event)
    }

    func route(
        _ event: AcceptedRawInputEvent,
        pointerConstraintLifecycleEvent: PointerConstraintLifecycleEvent? = nil
    ) -> [InputEvent] {
        guard
            let routed = routeOne(
                event.raw,
                pointerConstraintLifecycleEvent: pointerConstraintLifecycleEvent
            )
        else {
            return []
        }

        return [routed] + unknownProtocolValueDiagnostics(for: event.raw)
    }

    private func routeOne(
        _ event: RawInputEvent,
        pointerConstraintLifecycleEvent: PointerConstraintLifecycleEvent?
    ) -> InputEvent? {
        switch event.kind {
        case .seat(let snapshot):
            applySeatSnapshot(event, snapshot)
            return routedEvent(
                event,
                target: .display,
                kind: .seat(.changed(SeatStateSnapshot(snapshot)))
            )
        case .seatRemoved:
            deviceGraph.removeSeat(event.seatID)
            clearTabletFocuses()
            return routedEvent(event, target: .display, kind: .seat(.removed))
        case .diagnostic(let diagnostic):
            return routedEvent(
                event,
                target: .display,
                kind: .diagnostic(convert(diagnostic))
            )
        case .pointer(let pointerEvent):
            return routePointer(
                event,
                pointerEvent,
                pointerConstraintLifecycleEvent: pointerConstraintLifecycleEvent
            )
        case .keyboard(let keyboardEvent):
            return routeKeyboard(event, keyboardEvent)
        case .touch(let touchEvent):
            return routeTouch(event, touchEvent)
        case .tablet(let tabletEvent):
            return routeTablet(event, tabletEvent)
        }
    }

    // swiftlint:disable:next function_body_length
    private func routePointer(
        _ rawEvent: RawInputEvent,
        _ pointerEvent: RawPointerEvent,
        pointerConstraintLifecycleEvent: PointerConstraintLifecycleEvent?
    ) -> InputEvent? {
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
                        PointerLocation(waylandX: enter.x, waylandY: enter.y),
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
                        PointerLocation(waylandX: motion.x, waylandY: motion.y),
                        time: WaylandTimestampMilliseconds(rawValue: motion.time)
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
                            time: WaylandTimestampMilliseconds(rawValue: button.time),
                            button: PointerButtonCode(rawValue: button.button),
                            state: ButtonState(button.state)
                        )
                    )
                )
            )
        case .axis(let axis):
            return routedEvent(
                rawEvent,
                target: target(forFocusedSurface: focusedPointerSurface(for: rawEvent.seatID)),
                kind: .pointer(.axis(PointerAxisEvent(axis)))
            )
        case .relativeMotion(let motion):
            return routedEvent(
                rawEvent,
                target: target(forFocusedSurface: focusedPointerSurface(for: rawEvent.seatID)),
                kind: .pointer(
                    .relativeMotion(
                        RelativePointerMotionEvent(
                            time: WaylandTimestampMicroseconds(
                                rawValue: motion.timestampMicroseconds
                            ),
                            delta: PointerDelta(
                                dx: motion.dx.doubleValue,
                                dy: motion.dy.doubleValue
                            ),
                            unacceleratedDelta: PointerDelta(
                                dx: motion.dxUnaccelerated.doubleValue,
                                dy: motion.dyUnaccelerated.doubleValue
                            )
                        )
                    )
                )
            )
        case .constraint(let constraint):
            return routePointerConstraint(
                rawEvent,
                constraint,
                lifecycleEvent: pointerConstraintLifecycleEvent
            )
        }
    }

    private func routePointerConstraint(
        _ rawEvent: RawInputEvent,
        _ constraint: RawPointerConstraintEvent,
        lifecycleEvent: PointerConstraintLifecycleEvent?
    ) -> InputEvent? {
        routePointerConstraintLifecycle(
            rawEvent,
            constraint,
            lifecycleEvent: lifecycleEvent
        )
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
    private func routePointerConstraintLifecycle(
        _ rawEvent: RawInputEvent,
        _ constraint: RawPointerConstraintEvent,
        lifecycleEvent: PointerConstraintLifecycleEvent?
    ) -> InputEvent? {
        guard let lifecycleEvent else { return nil }

        let surfaceID: RawObjectID

        switch constraint {
        case .locked(_, let targetSurfaceID):
            surfaceID = targetSurfaceID
            guard case .activated(let id) = lifecycleEvent, id.kind == .locked else { return nil }
        case .unlocked(_, let targetSurfaceID):
            surfaceID = targetSurfaceID
            guard isTerminal(lifecycleEvent, for: .locked) else { return nil }
        case .confined(_, let targetSurfaceID):
            surfaceID = targetSurfaceID
            guard case .activated(let id) = lifecycleEvent, id.kind == .confined else { return nil }
        case .unconfined(_, let targetSurfaceID):
            surfaceID = targetSurfaceID
            guard isTerminal(lifecycleEvent, for: .confined) else { return nil }
        }

        return routedEvent(
            rawEvent,
            target: target(for: surfaceID),
            kind: .pointer(.constraintLifecycle(lifecycleEvent))
        )
    }

    private func isTerminal(
        _ lifecycleEvent: PointerConstraintLifecycleEvent,
        for kind: PointerConstraintKind
    ) -> Bool {
        switch lifecycleEvent {
        case .inactivePersistent(let id), .defunctOneShot(let id):
            id.kind == kind
        case .activated:
            false
        }
    }

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
                            format: KeyboardKeymapFormat(keymap.format),
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
                        pressedKeys: enter.pressedKeys.map(EvdevKeycode.init(rawValue:))
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
                            time: WaylandTimestampMilliseconds(rawValue: key.time),
                            rawKeycode: EvdevKeycode(rawValue: key.evdevKeycode),
                            state: KeyState(key.state)
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
            seatID: SeatID(rawEvent.seatID),
            target: target,
            kind: kind
        )
    }

    func target(for surfaceID: RawObjectID?) -> InputEventTarget {
        guard let surfaceID else {
            return .unmanagedSurface
        }
        guard let surfaceTarget = surfaceTarget(for: surfaceID) else {
            return .unmanagedSurface
        }

        return .surface(surfaceTarget)
    }

    func target(forFocusedSurface surfaceID: RawObjectID?) -> InputEventTarget {
        guard let surfaceID else {
            return .focusless
        }

        return target(for: surfaceID)
    }

    func windowID(for surfaceID: RawObjectID?) -> WindowID? {
        guard let surfaceID else {
            return nil
        }

        return surfaces[surfaceID]?.windowID
    }

    func surfaceTarget(for surfaceID: RawObjectID?) -> SurfaceTarget? {
        guard let surfaceID else {
            return nil
        }

        return surfaces[surfaceID]?.target
    }
}
