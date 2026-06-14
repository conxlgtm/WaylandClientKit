extension WaylandDisplay {
    public func relativePointer(
        seatID: SeatID
    ) throws -> RelativePointerSubscription {
        let id = try pointerCaptureCore().createRelativePointerSubscription(seatID: seatID)
        return RelativePointerSubscription(id: id, display: self)
    }

    public func lockPointer(
        window: Window,
        seatID: SeatID,
        cursorHint: PointerLocation? = nil,
        region: PointerConstraintRegion? = nil,
        lifetime: PointerConstraintLifetime = .oneShot
    ) throws -> PointerConstraint {
        guard window.isOwned(by: self) else {
            throw PointerCaptureError.foreignWindow(window.id)
        }

        let id = try pointerCaptureCore().lockPointer(
            windowID: window.id,
            seatID: seatID,
            cursorHint: cursorHint,
            region: region,
            lifetime: lifetime
        )
        return PointerConstraint(id: id, display: self)
    }

    public func confinePointer(
        window: Window,
        seatID: SeatID,
        region: PointerConstraintRegion? = nil,
        lifetime: PointerConstraintLifetime = .oneShot
    ) throws -> PointerConstraint {
        guard window.isOwned(by: self) else {
            throw PointerCaptureError.foreignWindow(window.id)
        }

        let id = try pointerCaptureCore().confinePointer(
            windowID: window.id,
            seatID: seatID,
            region: region,
            lifetime: lifetime
        )
        return PointerConstraint(id: id, display: self)
    }

    public func requestPointerWarp(
        window: Window,
        seatID: SeatID,
        position: LogicalOffset,
        serial: InputSerial
    ) throws {
        guard window.isOwned(by: self) else {
            throw PointerWarpError.foreignWindow(window.id)
        }

        try pointerWarpCore().requestPointerWarp(
            windowID: window.id,
            seatID: seatID,
            position: position,
            serial: serial
        )
    }

    public func destroyRelativePointerSubscription(
        _ subscription: RelativePointerSubscription
    ) throws {
        guard subscription.isOwned(by: self) else {
            throw PointerCaptureError.foreignRelativePointerSubscription(subscription.id)
        }

        try pointerCaptureCore().destroyRelativePointerSubscription(subscription.id)
    }

    public func destroyPointerConstraint(_ constraint: PointerConstraint) throws {
        guard constraint.isOwned(by: self) else {
            throw PointerCaptureError.foreignPointerConstraint(constraint.id)
        }

        try pointerCaptureCore().destroyPointerConstraint(constraint.id)
    }

    private func pointerCaptureCore() throws -> DisplayCore {
        do {
            return try requireCore()
        } catch ClientError.display(.closed) {
            throw PointerCaptureError.displayClosed
        }
    }

    private func pointerWarpCore() throws -> DisplayCore {
        do {
            return try requireCore()
        } catch ClientError.display(.closed) {
            throw PointerWarpError.displayClosed
        }
    }
}
