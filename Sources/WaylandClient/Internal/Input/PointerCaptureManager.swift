import WaylandRaw

private enum ManagedPointerConstraint {
    case locked(RawLockedPointer, region: RawRegion?)
    case confined(RawConfinedPointer, region: RawRegion?)

    var id: PointerConstraintID {
        switch self {
        case .locked(let pointer, _):
            PointerConstraintID(pointer.identity)
        case .confined(let pointer, _):
            PointerConstraintID(pointer.identity)
        }
    }

    func destroy() {
        switch self {
        case .locked(let pointer, let region):
            pointer.destroy()
            region?.destroy()
        case .confined(let pointer, let region):
            pointer.destroy()
            region?.destroy()
        }
    }
}

package final class PointerCaptureManager {
    private let connection: RawDisplayConnection
    private var nextRelativePointerSubscriptionID: UInt64 = 1
    private var relativePointers:
        [RelativePointerSubscriptionID: (seatID: SeatID, pointer: RawRelativePointer)] = [:]
    private var constraints:
        [PointerConstraintID: (seatID: SeatID, surfaceID: RawObjectID, constraint: ManagedPointerConstraint)] =
            [:]
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

        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let manager) = globals.extensions.relativePointerManager else {
            throw PointerCaptureError.unavailable(.relativePointer)
        }
        let seat = try requireSeat(seatID, globals: globals)
        let relativePointer = try manager.relativePointer(
            for: seat,
            eventSink: connection.inputEventSink
        )
        let subscriptionID = allocateRelativePointerSubscriptionID()
        relativePointers[subscriptionID] = (seatID: seatID, pointer: relativePointer)
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

        if let cursorHint {
            constraint.pointer.setCursorPositionHint(
                x: WaylandFixed(pointerLocationCoordinate: cursorHint.x),
                y: WaylandFixed(pointerLocationCoordinate: cursorHint.y)
            )
        }

        let managed = ManagedPointerConstraint.locked(constraint.pointer, region: constraint.region)
        return storeConstraint(
            managed,
            seatID: seatID,
            surfaceID: surface.objectID
        )
    }

    package func confinePointer(
        surface: RawSurface,
        seatID: SeatID,
        region: PointerConstraintRegion?,
        lifetime: PointerConstraintLifetime
    ) throws -> PointerConstraintID {
        connection.preconditionIsOwnerThread()
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

        let managed = ManagedPointerConstraint.confined(
            constraint.pointer,
            region: constraint.region
        )
        return storeConstraint(
            managed,
            seatID: seatID,
            surfaceID: surface.objectID
        )
    }

    package func destroyRelativePointerSubscription(
        _ id: RelativePointerSubscriptionID
    ) throws {
        connection.preconditionIsOwnerThread()
        guard let pointer = relativePointers.removeValue(forKey: id)?.pointer else {
            throw PointerCaptureError.unknownRelativePointerSubscription(id)
        }

        pointer.destroy()
    }

    package func destroyPointerConstraint(_ id: PointerConstraintID) throws {
        connection.preconditionIsOwnerThread()
        guard let constraint = constraints.removeValue(forKey: id)?.constraint else {
            throw PointerCaptureError.unknownPointerConstraint(id)
        }

        constraint.destroy()
    }

    package func removeSeat(_ seatID: SeatID) {
        connection.preconditionIsOwnerThread()
        let relativeIDs = relativePointers.filter { $0.value.seatID == seatID }.map(\.key)
        for id in relativeIDs {
            relativePointers.removeValue(forKey: id)?.pointer.destroy()
        }

        let constraintIDs = constraints.filter { $0.value.seatID == seatID }.map(\.key)
        for id in constraintIDs {
            constraints.removeValue(forKey: id)?.constraint.destroy()
        }
    }

    package func removeSurface(_ surfaceID: RawObjectID) {
        connection.preconditionIsOwnerThread()
        let constraintIDs = constraints.filter { $0.value.surfaceID == surfaceID }.map(\.key)
        for id in constraintIDs {
            constraints.removeValue(forKey: id)?.constraint.destroy()
        }
    }

    package func shutdown() {
        connection.preconditionIsOwnerThread()
        guard !isShutDown else { return }

        isShutDown = true
        for relativePointer in relativePointers.values {
            relativePointer.pointer.destroy()
        }
        for pointerConstraint in constraints.values {
            pointerConstraint.constraint.destroy()
        }
        relativePointers.removeAll()
        constraints.removeAll()
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
        surfaceID: RawObjectID
    ) -> PointerConstraintID {
        let id = constraint.id
        constraints[id] = (seatID: seatID, surfaceID: surfaceID, constraint: constraint)
        return id
    }

    private func requireSeat(_ seatID: SeatID, globals: BoundGlobals) throws -> RawSeat {
        guard let seat = globals.seatRegistry.seat(for: RawSeatID(seatID)) else {
            throw PointerCaptureError.unknownSeat(seatID)
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
        defer { nextRelativePointerSubscriptionID += 1 }
        return RelativePointerSubscriptionID(rawValue: nextRelativePointerSubscriptionID)
    }
}

extension RawPointerConstraintLifetime {
    package init(_ lifetime: PointerConstraintLifetime) {
        switch lifetime {
        case .oneShot:
            self = .oneShot
        case .persistent:
            self = .persistent
        }
    }
}

extension WaylandFixed {
    package init(pointerLocationCoordinate coordinate: Double) {
        self.init(rawValue: Int32((coordinate * 256.0).rounded()))
    }
}
