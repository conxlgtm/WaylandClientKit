import WaylandRaw

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
            target: target(for: down.surfaceID),
            kind: .touch(
                .down(TouchDownEvent(down))
            )
        )
    }

    func routeTouchUp(
        _ rawEvent: RawInputEvent,
        _ up: RawTouchUp
    ) -> InputEvent {
        let target = target(
            forFocusedSurface: focusedTouchSurface(for: rawEvent.seatID, touchID: up.id)
        )
        clearTouchFocus(seatID: rawEvent.seatID, touchID: up.id)
        return routedEvent(
            rawEvent,
            target: target,
            kind: .touch(
                .up(TouchUpEvent(up))
            )
        )
    }

    func routeTouchMotion(
        _ rawEvent: RawInputEvent,
        _ motion: RawTouchMotion
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            target: target(
                forFocusedSurface: focusedTouchSurface(
                    for: rawEvent.seatID,
                    touchID: motion.id
                )
            ),
            kind: .touch(
                .motion(TouchMotionEvent(motion))
            )
        )
    }

    func routeTouchShape(
        _ rawEvent: RawInputEvent,
        _ shape: RawTouchShape
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            target: target(
                forFocusedSurface: focusedTouchSurface(
                    for: rawEvent.seatID,
                    touchID: shape.id
                )
            ),
            kind: .touch(
                .shape(TouchShapeEvent(shape))
            )
        )
    }

    func routeTouchOrientation(
        _ rawEvent: RawInputEvent,
        _ orientation: RawTouchOrientation
    ) -> InputEvent {
        routedEvent(
            rawEvent,
            target: target(
                forFocusedSurface: focusedTouchSurface(
                    for: rawEvent.seatID,
                    touchID: orientation.id
                )
            ),
            kind: .touch(
                .orientation(TouchOrientationEvent(orientation))
            )
        )
    }
}
