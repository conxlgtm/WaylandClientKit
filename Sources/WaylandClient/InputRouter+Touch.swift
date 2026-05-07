import WaylandRaw

extension InputRouter {
    private func touchID(_ rawID: RawTouchID) -> TouchID {
        TouchID(rawValue: rawID.rawValue)
    }

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
                .down(
                    TouchDownEvent(
                        serial: InputSerial(rawValue: down.serial),
                        time: down.time,
                        id: touchID(down.id),
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
        let target = target(
            forFocusedSurface: focusedTouchSurface(for: rawEvent.seatID, touchID: up.id)
        )
        clearTouchFocus(seatID: rawEvent.seatID, touchID: up.id)
        return routedEvent(
            rawEvent,
            target: target,
            kind: .touch(
                .up(
                    TouchUpEvent(
                        serial: InputSerial(rawValue: up.serial),
                        time: up.time,
                        id: touchID(up.id)
                    )
                )
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
                .motion(
                    TouchMotionEvent(
                        time: motion.time,
                        id: touchID(motion.id),
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
            target: target(
                forFocusedSurface: focusedTouchSurface(
                    for: rawEvent.seatID,
                    touchID: shape.id
                )
            ),
            kind: .touch(
                .shape(
                    TouchShapeEvent(
                        id: touchID(shape.id),
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
            target: target(
                forFocusedSurface: focusedTouchSurface(
                    for: rawEvent.seatID,
                    touchID: orientation.id
                )
            ),
            kind: .touch(
                .orientation(
                    TouchOrientationEvent(
                        id: touchID(orientation.id),
                        orientation: orientation.orientation.doubleValue
                    )
                )
            )
        )
    }
}
