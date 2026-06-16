import WaylandRaw

extension SeatID {
    package init(_ raw: RawSeatID) {
        self.init(rawValue: raw.rawValue)
    }
}

extension RawSeatID {
    package init(_ seatID: SeatID) {
        self.init(rawValue: seatID.rawValue)
    }
}

extension OutputID {
    package init(_ raw: RawOutputID) {
        self.init(rawValue: raw.rawValue)
    }
}

extension RawOutputID {
    package init(_ outputID: OutputID) {
        self.init(rawValue: outputID.rawValue)
    }
}

extension ButtonState {
    package init(_ raw: RawPointerButtonState) {
        self.init(rawValue: raw.rawValue)
    }
}

extension KeyState {
    package init(_ raw: RawKeyboardKeyState) {
        self.init(rawValue: raw.rawValue)
    }
}

extension KeyboardKeymapFormat {
    package init(_ raw: RawKeyboardKeymapFormat) {
        self.init(rawValue: raw.rawValue)
    }
}

extension PointerAxis {
    package init(_ raw: RawPointerAxis) {
        self.init(rawValue: raw.rawValue)
    }
}

extension PointerAxisSource {
    package init(_ raw: RawPointerAxisSource) {
        self.init(rawValue: raw.rawValue)
    }
}

extension PointerAxisRelativeDirection {
    package init(_ raw: RawPointerAxisRelativeDirection) {
        self.init(rawValue: raw.rawValue)
    }
}

extension RawPointerGestureEvent {
    package var beginSurfaceID: RawObjectID? {
        switch self {
        case .swipe(let swipe):
            swipe.beginSurfaceID
        case .pinch(let pinch):
            pinch.beginSurfaceID
        case .hold(let hold):
            hold.beginSurfaceID
        }
    }
}

extension RawPointerSwipeGestureEvent {
    package var beginSurfaceID: RawObjectID? {
        guard case .begin(_, _, let surfaceID, _) = self else {
            return nil
        }

        return surfaceID
    }
}

extension RawPointerPinchGestureEvent {
    package var beginSurfaceID: RawObjectID? {
        guard case .begin(_, _, let surfaceID, _) = self else {
            return nil
        }

        return surfaceID
    }
}

extension RawPointerHoldGestureEvent {
    package var beginSurfaceID: RawObjectID? {
        guard case .begin(_, _, let surfaceID, _) = self else {
            return nil
        }

        return surfaceID
    }
}

extension PointerGestureEvent {
    package init(_ raw: RawPointerGestureEvent) {
        switch raw {
        case .swipe(let swipe):
            self = .swipe(PointerSwipeGestureEvent(swipe))
        case .pinch(let pinch):
            self = .pinch(PointerPinchGestureEvent(pinch))
        case .hold(let hold):
            self = .hold(PointerHoldGestureEvent(hold))
        }
    }
}

extension PointerSwipeGestureEvent {
    package init(_ raw: RawPointerSwipeGestureEvent) {
        switch raw {
        case .begin(let serial, let time, _, let fingers):
            self = .begin(
                serial: InputSerial(rawValue: serial),
                time: WaylandTimestampMilliseconds(rawValue: time),
                fingers: fingers
            )
        case .update(let time, let dx, let dy):
            self = .update(
                time: WaylandTimestampMilliseconds(rawValue: time),
                delta: PointerDelta(dx: dx.doubleValue, dy: dy.doubleValue)
            )
        case .end(let serial, let time, false):
            self = .end(
                serial: InputSerial(rawValue: serial),
                time: WaylandTimestampMilliseconds(rawValue: time)
            )
        case .end(let serial, let time, true):
            self = .cancel(
                serial: InputSerial(rawValue: serial),
                time: WaylandTimestampMilliseconds(rawValue: time)
            )
        }
    }
}

extension PointerPinchGestureEvent {
    package init(_ raw: RawPointerPinchGestureEvent) {
        switch raw {
        case .begin(let serial, let time, _, let fingers):
            self = .begin(
                serial: InputSerial(rawValue: serial),
                time: WaylandTimestampMilliseconds(rawValue: time),
                fingers: fingers
            )
        case .update(let update):
            self = .update(
                time: WaylandTimestampMilliseconds(rawValue: update.time),
                delta: PointerDelta(dx: update.dx.doubleValue, dy: update.dy.doubleValue),
                scale: update.scale.doubleValue,
                rotation: update.rotation.doubleValue
            )
        case .end(let serial, let time, false):
            self = .end(
                serial: InputSerial(rawValue: serial),
                time: WaylandTimestampMilliseconds(rawValue: time)
            )
        case .end(let serial, let time, true):
            self = .cancel(
                serial: InputSerial(rawValue: serial),
                time: WaylandTimestampMilliseconds(rawValue: time)
            )
        }
    }
}

extension PointerHoldGestureEvent {
    package init(_ raw: RawPointerHoldGestureEvent) {
        switch raw {
        case .begin(let serial, let time, _, let fingers):
            self = .begin(
                serial: InputSerial(rawValue: serial),
                time: WaylandTimestampMilliseconds(rawValue: time),
                fingers: fingers
            )
        case .end(let serial, let time, false):
            self = .end(
                serial: InputSerial(rawValue: serial),
                time: WaylandTimestampMilliseconds(rawValue: time)
            )
        case .end(let serial, let time, true):
            self = .cancel(
                serial: InputSerial(rawValue: serial),
                time: WaylandTimestampMilliseconds(rawValue: time)
            )
        }
    }
}
