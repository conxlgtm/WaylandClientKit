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
        [PointerConstraintID: (
            seatID: SeatID, surfaceID: RawObjectID, constraint: ManagedPointerConstraint
        )] =
            [:]
    private var relativePointerRegistry = RelativePointerSubscriptionRegistry()
    private var constraintRegistry = PointerConstraintRegistry()
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
        relativePointers[subscriptionID] = (seatID: seatID, pointer: relativePointer)
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
        try constraintRegistry.preflight(surfaceID: surface.objectID, seatID: seatID)
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

        if let fixedCursorHint {
            constraint.pointer.setCursorPositionHint(
                x: fixedCursorHint.x,
                y: fixedCursorHint.y
            )
            surface.commit()
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
        try constraintRegistry.preflight(surfaceID: surface.objectID, seatID: seatID)
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

        _ = relativePointerRegistry.remove(id)
        pointer.destroy()
    }

    package func destroyPointerConstraint(_ id: PointerConstraintID) throws {
        connection.preconditionIsOwnerThread()
        guard let constraint = constraints.removeValue(forKey: id)?.constraint else {
            throw PointerCaptureError.unknownPointerConstraint(id)
        }

        _ = constraintRegistry.remove(id)
        constraint.destroy()
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
        let relativeIDs = relativePointers.filter { $0.value.seatID == seatID }.map(\.key)
        for id in relativeIDs {
            _ = relativePointerRegistry.remove(id)
            relativePointers.removeValue(forKey: id)?.pointer.destroy()
        }

        let constraintIDs = constraints.filter { $0.value.seatID == seatID }.map(\.key)
        for id in constraintIDs {
            _ = constraintRegistry.remove(id)
            constraints.removeValue(forKey: id)?.constraint.destroy()
        }
    }

    package func removeSurface(_ surfaceID: RawObjectID) {
        connection.preconditionIsOwnerThread()
        let constraintIDs = constraints.filter { $0.value.surfaceID == surfaceID }.map(\.key)
        for id in constraintIDs {
            _ = constraintRegistry.remove(id)
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
        relativePointerRegistry.removeAll()
        constraintRegistry.removeAll()
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
        surfaceID: RawObjectID
    ) -> PointerConstraintID {
        let id = constraint.id
        constraints[id] = (seatID: seatID, surfaceID: surfaceID, constraint: constraint)
        constraintRegistry.insert(id: id, surfaceID: surfaceID, seatID: seatID)
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

    package static func requirePointerDevice(on seat: RawSeat, seatID: SeatID) throws {
        guard seat.hasPointerDevice else {
            throw PointerCaptureError.pointerUnavailable(seatID)
        }
    }
}

package struct FixedPointerLocation: Equatable, Sendable {
    package let x: WaylandFixed
    package let y: WaylandFixed

    package init(_ location: PointerLocation) throws {
        do {
            x = try WaylandFixed(pointerLocationCoordinate: location.x)
            y = try WaylandFixed(pointerLocationCoordinate: location.y)
        } catch {
            throw PointerCaptureError.invalidCursorHint(location)
        }
    }
}

package struct PointerConstraintKey: Equatable, Hashable, Sendable {
    package let surfaceID: RawObjectID
    package let seatID: SeatID

    package init(surfaceID constraintSurfaceID: RawObjectID, seatID constraintSeatID: SeatID) {
        surfaceID = constraintSurfaceID
        seatID = constraintSeatID
    }
}

package struct RelativePointerSubscriptionRegistry {
    private var seatByID: [RelativePointerSubscriptionID: SeatID] = [:]
    private var idBySeat: [SeatID: RelativePointerSubscriptionID] = [:]

    package init() {
        // Exposes the synthesized initializer at package scope.
    }

    package func preflight(seatID: SeatID) throws {
        guard idBySeat[seatID] == nil else {
            throw PointerCaptureError.relativePointerAlreadySubscribed(seatID: seatID)
        }
    }

    package mutating func insert(id: RelativePointerSubscriptionID, seatID: SeatID) {
        seatByID[id] = seatID
        idBySeat[seatID] = id
    }

    @discardableResult
    package mutating func remove(_ id: RelativePointerSubscriptionID) -> SeatID? {
        guard let seatID = seatByID.removeValue(forKey: id) else { return nil }
        idBySeat.removeValue(forKey: seatID)
        return seatID
    }

    package mutating func removeAll() {
        seatByID.removeAll()
        idBySeat.removeAll()
    }
}

package struct PointerConstraintRegistry {
    private var keyByID: [PointerConstraintID: PointerConstraintKey] = [:]
    private var idByKey: [PointerConstraintKey: PointerConstraintID] = [:]

    package init() {
        // Exposes the synthesized initializer at package scope.
    }

    package func preflight(surfaceID: RawObjectID, seatID: SeatID) throws {
        let key = PointerConstraintKey(surfaceID: surfaceID, seatID: seatID)
        guard idByKey[key] == nil else {
            throw PointerCaptureError.alreadyConstrained(seatID: seatID)
        }
    }

    package mutating func insert(
        id: PointerConstraintID,
        surfaceID: RawObjectID,
        seatID: SeatID
    ) {
        let key = PointerConstraintKey(surfaceID: surfaceID, seatID: seatID)
        keyByID[id] = key
        idByKey[key] = id
    }

    @discardableResult
    package mutating func remove(_ id: PointerConstraintID) -> PointerConstraintKey? {
        guard let key = keyByID.removeValue(forKey: id) else { return nil }
        idByKey.removeValue(forKey: key)
        return key
    }

    package mutating func removeAll() {
        keyByID.removeAll()
        idByKey.removeAll()
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
    package init(pointerLocationCoordinate coordinate: Double) throws {
        let scaled = (coordinate * 256.0).rounded()
        guard
            coordinate.isFinite,
            scaled.isFinite,
            scaled >= Double(Int32.min),
            scaled <= Double(Int32.max)
        else {
            throw PointerCaptureError.invalidCursorHint(PointerLocation(x: coordinate, y: 0))
        }

        self.init(rawValue: Int32(scaled))
    }
}
