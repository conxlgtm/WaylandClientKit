import WaylandRaw

extension DisplaySession {
    package func createRelativePointerOnOwnerThread(
        seatID: SeatID
    ) throws -> RelativePointerSubscriptionID {
        connection.preconditionIsOwnerThread()
        return try pointerCaptureManager.createRelativePointer(seatID: seatID)
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

    package func destroyRelativePointerSubscriptionOnOwnerThread(
        _ id: RelativePointerSubscriptionID
    ) throws {
        connection.preconditionIsOwnerThread()
        try pointerCaptureManager.destroyRelativePointerSubscription(id)
    }

    package func destroyPointerConstraintOnOwnerThread(_ id: PointerConstraintID) throws {
        connection.preconditionIsOwnerThread()
        try pointerCaptureManager.destroyPointerConstraint(id)
    }
}
