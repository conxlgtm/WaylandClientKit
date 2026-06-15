import WaylandRaw

extension DisplaySession {
    package func createRelativePointerOnOwnerThread(
        seatID: SeatID
    ) throws -> RelativePointerSubscriptionID {
        connection.preconditionIsOwnerThread()
        return try pointerCaptureManager.createRelativePointer(seatID: seatID)
    }

    package func createPointerGesturesOnOwnerThread(
        seatID: SeatID
    ) throws -> (id: PointerGestureSubscriptionID, version: UInt32) {
        connection.preconditionIsOwnerThread()
        return try pointerCaptureManager.createPointerGestures(seatID: seatID)
    }

    package func lockPointerOnOwnerThread(
        surface: RawSurface,
        seatID: SeatID,
        cursorHint: PointerLocation?,
        region: PointerConstraintRegion?,
        lifetime: PointerConstraintLifetime
    ) throws -> PointerConstraintID {
        connection.preconditionIsOwnerThread()
        return try pointerCaptureManager.lockPointer(
            surface: surface,
            seatID: seatID,
            cursorHint: cursorHint,
            region: region,
            lifetime: lifetime
        )
    }

    package func confinePointerOnOwnerThread(
        surface: RawSurface,
        seatID: SeatID,
        region: PointerConstraintRegion?,
        lifetime: PointerConstraintLifetime
    ) throws -> PointerConstraintID {
        connection.preconditionIsOwnerThread()
        return try pointerCaptureManager.confinePointer(
            surface: surface,
            seatID: seatID,
            region: region,
            lifetime: lifetime
        )
    }

    package func requestPointerWarpOnOwnerThread(
        surface: RawSurface,
        windowSize: PositiveLogicalSize,
        seatID: SeatID,
        position: LogicalOffset,
        serial: InputSerial
    ) throws {
        connection.preconditionIsOwnerThread()
        try pointerCaptureManager.requestPointerWarp(
            surface: surface,
            windowSize: windowSize,
            seatID: seatID,
            position: position,
            serial: serial
        )
    }

    package func destroyRelativePointerSubscriptionOnOwnerThread(
        _ id: RelativePointerSubscriptionID
    ) throws {
        connection.preconditionIsOwnerThread()
        try pointerCaptureManager.destroyRelativePointerSubscription(id)
    }

    package func destroyPointerGestureSubscriptionOnOwnerThread(
        _ id: PointerGestureSubscriptionID
    ) throws {
        connection.preconditionIsOwnerThread()
        try pointerCaptureManager.destroyPointerGestureSubscription(id)
    }

    package func destroyPointerConstraintOnOwnerThread(_ id: PointerConstraintID) throws {
        connection.preconditionIsOwnerThread()
        try pointerCaptureManager.destroyPointerConstraint(id)
    }
}
