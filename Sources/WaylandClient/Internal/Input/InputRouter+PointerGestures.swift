import WaylandRaw

enum ActivePointerGestureKind: Hashable {
    case swipe
    case pinch
    case hold
}

struct ActivePointerGestureKey: Hashable {
    let seatID: RawSeatID
    let kind: ActivePointerGestureKind
}

struct ActivePointerGestureRoute {
    let surfaceID: RawObjectID?
    let target: InputEventTarget
}

extension InputRouter {
    func routePointerGesture(
        _ rawEvent: RawInputEvent,
        _ gesture: RawPointerGestureEvent
    ) -> InputEvent {
        let target = gestureTarget(rawEvent, gesture)
        clearPointerGestureRouteIfTerminal(rawEvent, gesture)
        return routedEvent(
            rawEvent,
            target: target,
            kind: .pointer(.gesture(PointerGestureEvent(gesture)))
        )
    }

    private func gestureTarget(
        _ rawEvent: RawInputEvent,
        _ gesture: RawPointerGestureEvent
    ) -> InputEventTarget {
        let key = ActivePointerGestureKey(
            seatID: rawEvent.seatID,
            kind: activeGestureKind(gesture)
        )
        if let surfaceID = gesture.beginSurfaceID {
            let target = target(for: surfaceID)
            activePointerGestureRoutes[key] = ActivePointerGestureRoute(
                surfaceID: surfaceID,
                target: target
            )
            return target
        }

        if let route = activePointerGestureRoutes[key] {
            return route.target
        }

        return target(forFocusedSurface: focusedPointerSurface(for: rawEvent.seatID))
    }

    private func clearPointerGestureRouteIfTerminal(
        _ rawEvent: RawInputEvent,
        _ gesture: RawPointerGestureEvent
    ) {
        guard pointerGestureIsTerminal(gesture) else { return }

        activePointerGestureRoutes.removeValue(
            forKey: ActivePointerGestureKey(
                seatID: rawEvent.seatID,
                kind: activeGestureKind(gesture)
            )
        )
    }
}

private func activeGestureKind(_ gesture: RawPointerGestureEvent) -> ActivePointerGestureKind {
    switch gesture {
    case .swipe:
        .swipe
    case .pinch:
        .pinch
    case .hold:
        .hold
    }
}

private func pointerGestureIsTerminal(_ gesture: RawPointerGestureEvent) -> Bool {
    switch gesture {
    case .swipe(.end),
        .pinch(.end),
        .hold(.end):
        true
    case .swipe(.begin),
        .swipe(.update),
        .pinch(.begin),
        .pinch(.update),
        .hold(.begin):
        false
    }
}
