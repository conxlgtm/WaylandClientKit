import WaylandRaw

private struct ManagedRelativePointerSubscription {
    let seatID: SeatID
    let pointer: RawRelativePointer
}

package final class PointerCaptureManager {  // swiftlint:disable:this type_body_length
    private let connection: RawDisplayConnection
    private var relativePointerSubscriptionIDs =
        IDGenerator<RelativePointerSubscriptionID>()
    private var pointerConstraintIDs = IDGenerator<PointerConstraintID>()
    private var relativePointers =
        DisplayResourceTable<RelativePointerSubscriptionID, ManagedRelativePointerSubscription>()
    private var relativePointerRegistry = RelativePointerSubscriptionRegistry()
    private var constraintRuntime = PointerConstraintRuntime()
    private var isShutDown = false

    package init(connection rawConnection: RawDisplayConnection) {
        connection = rawConnection
    }

    package func createRelativePointer(
        seatID: SeatID
    ) throws -> RelativePointerSubscriptionID {
        connection.preconditionIsOwnerThread()
        guard !isShutDown else {
            throw PointerCaptureError.displayClosed
        }

        try relativePointerRegistry.preflight(seatID: seatID)
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let manager) = globals.extensions.relativePointerManager else {
            throw PointerCaptureError.unavailable(.relativePointer)
        }
        let seat = try requireSeat(seatID, globals: globals)
        try Self.requirePointerDevice(on: seat, seatID: seatID)
        let relativePointer = try manager.relativePointer(
            for: seat,
            eventSink: connection.inputEventSink
        )
        let subscriptionID = allocateRelativePointerSubscriptionID()
        do {
            try relativePointers.insert(
                ManagedRelativePointerSubscription(
                    seatID: seatID,
                    pointer: relativePointer
                ),
                id: subscriptionID
            )
        } catch {
            relativePointer.destroy()
            throw error
        }
        relativePointerRegistry.insert(id: subscriptionID, seatID: seatID)
        return subscriptionID
    }

    package func lockPointer(
        surface: RawSurface,
        seatID: SeatID,
        cursorHint: PointerLocation?,
        region: PointerConstraintRegion?,
        lifetime: PointerConstraintLifetime
    ) throws -> PointerConstraintID {
        connection.preconditionIsOwnerThread()
        let fixedCursorHint = try cursorHint.map(FixedPointerLocation.init)
        try constraintRuntime.preflight(surfaceID: surface.objectID, seatID: seatID)
        let constraint = try createConstraint(
            surface: surface,
            seatID: seatID,
            region: region,
            lifetime: lifetime
        ) { manager, surface, seat, region, rawLifetime in
            try manager.lockPointer(
                surface: surface,
                seat: seat,
                region: region,
                lifetime: rawLifetime,
                eventSink: connection.inputEventSink
            )
        }
        let id = allocatePointerConstraintID(kind: .locked)

        if let fixedCursorHint {
            constraint.pointer.setCursorPositionHint(
                x: fixedCursorHint.x,
                y: fixedCursorHint.y
            )
            surface.commit()
        }

        let managed = ManagedPointerConstraint.locked(
            constraint.pointer,
            id: id,
            region: constraint.region
        )
        return storeConstraint(
            managed,
            seatID: seatID,
            surfaceID: surface.objectID,
            lifetime: lifetime
        )
    }

    package func confinePointer(
        surface: RawSurface,
        seatID: SeatID,
        region: PointerConstraintRegion?,
        lifetime: PointerConstraintLifetime
    ) throws -> PointerConstraintID {
        connection.preconditionIsOwnerThread()
        try constraintRuntime.preflight(surfaceID: surface.objectID, seatID: seatID)
        let constraint = try createConstraint(
            surface: surface,
            seatID: seatID,
            region: region,
            lifetime: lifetime
        ) { manager, surface, seat, region, rawLifetime in
            try manager.confinePointer(
                surface: surface,
                seat: seat,
                region: region,
                lifetime: rawLifetime,
                eventSink: connection.inputEventSink
            )
        }
        let id = allocatePointerConstraintID(kind: .confined)

        let managed = ManagedPointerConstraint.confined(
            constraint.pointer,
            id: id,
            region: constraint.region
        )
        return storeConstraint(
            managed,
            seatID: seatID,
            surfaceID: surface.objectID,
            lifetime: lifetime
        )
    }

    package func requestPointerWarp(
        surface: RawSurface,
        windowSize: PositiveLogicalSize,
        seatID: SeatID,
        position: LogicalOffset,
        serial: InputSerial
    ) throws {
        connection.preconditionIsOwnerThread()
        guard !isShutDown else {
            throw PointerWarpError.displayClosed
        }

        let fixedPosition = try FixedPointerWarpPosition(
            position: position,
            windowSize: windowSize
        )
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let warp) = globals.extensions.pointerWarp else {
            throw PointerWarpError.unavailable
        }
        let seat = try requirePointerWarpSeat(seatID, globals: globals)
        guard seat.hasPointerDevice else {
            throw PointerWarpError.pointerUnavailable(seatID)
        }

        do {
            try warp.warpPointer(
                surface: surface,
                seat: seat,
                x: fixedPosition.x,
                y: fixedPosition.y,
                serial: serial.rawValue
            )
        } catch RuntimeError.bindFailed("wl_pointer") {
            throw PointerWarpError.pointerUnavailable(seatID)
        } catch {
            throw PointerWarpError.requestFailed(String(describing: error))
        }
    }

    package func destroyRelativePointerSubscription(
        _ id: RelativePointerSubscriptionID
    ) throws {
        connection.preconditionIsOwnerThread()
        guard let pointer = relativePointers.remove(id)?.pointer else {
            throw PointerCaptureError.unknownRelativePointerSubscription(id)
        }

        _ = relativePointerRegistry.remove(id)
        pointer.destroy()
    }

    package func destroyPointerConstraint(_ id: PointerConstraintID) throws {
        connection.preconditionIsOwnerThread()
        try constraintRuntime.destroyPointerConstraint(id)
    }

    package func processRawInputEvent(_ event: RawInputEvent) -> PointerConstraintLifecycleEvent? {
        connection.preconditionIsOwnerThread()
        return constraintRuntime.processRawInputEvent(event)
    }

    package func removeSeat(_ seatID: SeatID) {
        connection.preconditionIsOwnerThread()
        removePointerState(for: seatID)
    }

    package func removePointerCapability(_ seatID: SeatID) {
        connection.preconditionIsOwnerThread()
        removePointerState(for: seatID)
    }

    private func removePointerState(for seatID: SeatID) {
        let relativeIDs = relativePointers.ids.filter { id in
            relativePointers.get(id)?.seatID == seatID
        }
        for id in relativeIDs {
            _ = relativePointerRegistry.remove(id)
            relativePointers.remove(id)?.pointer.destroy()
        }

        constraintRuntime.removeSeat(seatID)
    }

    package func removeSurface(_ surfaceID: RawObjectID) {
        connection.preconditionIsOwnerThread()
        constraintRuntime.removeSurface(surfaceID)
    }

    package func shutdown() {
        connection.preconditionIsOwnerThread()
        guard !isShutDown else { return }

        isShutDown = true
        for relativePointer in relativePointers.removeAll() {
            relativePointer.pointer.destroy()
        }
        relativePointerRegistry.removeAll()
        constraintRuntime.removeAll()
    }

    private func createConstraint<Pointer>(
        surface: RawSurface,
        seatID: SeatID,
        region: PointerConstraintRegion?,
        lifetime: PointerConstraintLifetime,
        create: (
            RawPointerConstraints,
            RawSurface,
            RawSeat,
            RawRegion?,
            RawPointerConstraintLifetime
        ) throws -> Pointer
    ) throws -> (pointer: Pointer, region: RawRegion?) {
        guard !isShutDown else {
            throw PointerCaptureError.displayClosed
        }

        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let manager) = globals.extensions.pointerConstraints else {
            throw PointerCaptureError.unavailable(.pointerConstraints)
        }
        let seat = try requireSeat(seatID, globals: globals)
        try Self.requirePointerDevice(on: seat, seatID: seatID)
        let rawRegion = try makeRegion(region, globals: globals)

        do {
            let pointer = try create(
                manager,
                surface,
                seat,
                rawRegion,
                RawPointerConstraintLifetime(lifetime)
            )
            return (pointer, rawRegion)
        } catch {
            rawRegion?.destroy()
            throw error
        }
    }

    private func storeConstraint(
        _ constraint: ManagedPointerConstraint,
        seatID: SeatID,
        surfaceID: RawObjectID,
        lifetime: PointerConstraintLifetime
    ) -> PointerConstraintID {
        let id = constraint.id
        constraintRuntime.insert(
            id: id,
            seatID: seatID,
            surfaceID: surfaceID,
            constraint: constraint,
            lifetime: lifetime
        )
        return id
    }

    private func allocatePointerConstraintID(kind: PointerConstraintKind) -> PointerConstraintID {
        PointerConstraintID(
            rawValue: pointerConstraintIDs.nextRawValueForCompositeID(),
            kind: kind
        )
    }

    private func requireSeat(_ seatID: SeatID, globals: BoundGlobals) throws -> RawSeat {
        guard let seat = globals.seatRegistry.seat(for: RawSeatID(seatID)) else {
            throw PointerCaptureError.unknownSeat(seatID)
        }

        return seat
    }

    private func requirePointerWarpSeat(
        _ seatID: SeatID,
        globals: BoundGlobals
    ) throws -> RawSeat {
        guard let seat = globals.seatRegistry.seat(for: RawSeatID(seatID)) else {
            throw PointerWarpError.unknownSeat(seatID)
        }

        return seat
    }

    private func makeRegion(
        _ region: PointerConstraintRegion?,
        globals: BoundGlobals
    ) throws -> RawRegion? {
        guard let region else { return nil }

        let rawRegion = try globals.compositor.createRegion()
        for rectangle in region.rectangles {
            rawRegion.add(
                x: rectangle.origin.x,
                y: rectangle.origin.y,
                width: rectangle.size.width.rawValue,
                height: rectangle.size.height.rawValue
            )
        }
        return rawRegion
    }

    private func allocateRelativePointerSubscriptionID() -> RelativePointerSubscriptionID {
        relativePointerSubscriptionIDs.next()
    }

    package static func requirePointerDevice(on seat: RawSeat, seatID: SeatID) throws {
        guard seat.hasPointerDevice else {
            throw PointerCaptureError.pointerUnavailable(seatID)
        }
    }
}
