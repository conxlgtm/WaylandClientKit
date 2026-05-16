import WaylandRaw

extension TouchID {
    package init(_ raw: RawTouchID) {
        self.init(rawValue: raw.rawValue)
    }
}

extension TouchDownEvent {
    package init(_ raw: RawTouchDown) {
        self.init(
            serial: InputSerial(rawValue: raw.serial),
            time: WaylandTimestampMilliseconds(rawValue: raw.time),
            id: TouchID(raw.id),
            location: PointerLocation(waylandX: raw.x, waylandY: raw.y)
        )
    }
}

extension TouchUpEvent {
    package init(_ raw: RawTouchUp) {
        self.init(
            serial: InputSerial(rawValue: raw.serial),
            time: WaylandTimestampMilliseconds(rawValue: raw.time),
            id: TouchID(raw.id)
        )
    }
}

extension TouchMotionEvent {
    package init(_ raw: RawTouchMotion) {
        self.init(
            time: WaylandTimestampMilliseconds(rawValue: raw.time),
            id: TouchID(raw.id),
            location: PointerLocation(waylandX: raw.x, waylandY: raw.y)
        )
    }
}

extension TouchShapeEvent {
    package init(_ raw: RawTouchShape) {
        self.init(
            id: TouchID(raw.id),
            major: raw.major.doubleValue,
            minor: raw.minor.doubleValue
        )
    }
}

extension TouchOrientationEvent {
    package init(_ raw: RawTouchOrientation) {
        self.init(
            id: TouchID(raw.id),
            orientation: raw.orientation.doubleValue
        )
    }
}
