import WaylandRaw

package struct ManagedPointerConstraint {
    private let destroyImplementation: () -> Void

    package let id: PointerConstraintID
    package let rawIdentity: RawPointerConstraintIdentity

    package init(
        id constraintID: PointerConstraintID,
        rawIdentity constraintRawIdentity: RawPointerConstraintIdentity,
        destroy: @escaping () -> Void
    ) {
        id = constraintID
        rawIdentity = constraintRawIdentity
        destroyImplementation = destroy
    }

    package static func locked(
        _ pointer: RawLockedPointer,
        id constraintID: PointerConstraintID,
        region: RawRegion?
    ) -> ManagedPointerConstraint {
        ManagedPointerConstraint(id: constraintID, rawIdentity: pointer.identity) {
            pointer.destroy()
            region?.destroy()
        }
    }

    package static func confined(
        _ pointer: RawConfinedPointer,
        id constraintID: PointerConstraintID,
        region: RawRegion?
    ) -> ManagedPointerConstraint {
        ManagedPointerConstraint(id: constraintID, rawIdentity: pointer.identity) {
            pointer.destroy()
            region?.destroy()
        }
    }

    package func destroy() {
        destroyImplementation()
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

package enum PointerConstraintLifecycle: Equatable, Sendable {
    case requested
    case active
    case inactivePersistent
}

package enum PointerConstraintLifecycleTransition: Equatable, Sendable {
    case activated(PointerConstraintID)
    case inactivePersistent(PointerConstraintID)
    case defunctOneShot(PointerConstraintID)
    case ignored

    package var lifecycleEvent: PointerConstraintLifecycleEvent? {
        switch self {
        case .activated(let id):
            .activated(id)
        case .inactivePersistent(let id):
            .inactivePersistent(id)
        case .defunctOneShot(let id):
            .defunctOneShot(id)
        case .ignored:
            nil
        }
    }
}

private struct PointerConstraintRecord {
    let key: PointerConstraintKey
    let lifetime: PointerConstraintLifetime
    let constraint: ManagedPointerConstraint
    var lifecycle: PointerConstraintLifecycle
}

package struct PointerConstraintRuntime {
    private var constraintsByID: [PointerConstraintID: PointerConstraintRecord] = [:]
    private var idByKey: [PointerConstraintKey: PointerConstraintID] = [:]
    private var idByRawIdentity: [RawPointerConstraintIdentity: PointerConstraintID] = [:]

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
        seatID: SeatID,
        surfaceID: RawObjectID,
        constraint: ManagedPointerConstraint,
        lifetime: PointerConstraintLifetime
    ) {
        let key = PointerConstraintKey(surfaceID: surfaceID, seatID: seatID)
        precondition(constraintsByID[id] == nil, "Pointer constraint ID is already in use")
        precondition(idByKey[key] == nil, "Surface and seat already have a pointer constraint")
        precondition(
            idByRawIdentity[constraint.rawIdentity] == nil,
            "Raw pointer constraint identity is already in use"
        )
        constraintsByID[id] = PointerConstraintRecord(
            key: key,
            lifetime: lifetime,
            constraint: constraint,
            lifecycle: .requested
        )
        idByKey[key] = id
        idByRawIdentity[constraint.rawIdentity] = id
        preconditionIndicesMatchRecords()
    }

    package mutating func destroyPointerConstraint(_ id: PointerConstraintID) throws {
        guard let record = removeRecord(id) else {
            throw PointerCaptureError.unknownPointerConstraint(id)
        }

        record.constraint.destroy()
    }

    package mutating func processRawInputEvent(
        _ event: RawInputEvent
    ) -> PointerConstraintLifecycleEvent? {
        guard case .pointer(.constraint(let constraintEvent)) = event.kind else { return nil }
        guard let id = idByRawIdentity[constraintEvent.identity] else { return nil }

        let protocolEvent = PointerConstraintProtocolEvent(constraintEvent, id: id)
        return transition(id: id, event: protocolEvent).lifecycleEvent
    }

    package mutating func removeSeat(_ seatID: SeatID) {
        let constraintIDs = constraintsByID.filter { $0.value.key.seatID == seatID }.map(\.key)
        destroyAndRemoveConstraints(constraintIDs)
    }

    package mutating func removeSurface(_ surfaceID: RawObjectID) {
        let constraintIDs = constraintsByID.filter { $0.value.key.surfaceID == surfaceID }.map(
            \.key)
        destroyAndRemoveConstraints(constraintIDs)
    }

    package mutating func removeAll() {
        let constraints = constraintsByID.values.map(\.constraint)
        constraintsByID.removeAll()
        idByKey.removeAll()
        idByRawIdentity.removeAll()
        preconditionIndicesMatchRecords()
        for constraint in constraints {
            constraint.destroy()
        }
    }

    package func lifecycle(for id: PointerConstraintID) -> PointerConstraintLifecycle? {
        constraintsByID[id]?.lifecycle
    }

    private mutating func transition(
        id: PointerConstraintID,
        event: PointerConstraintProtocolEvent
    ) -> PointerConstraintLifecycleTransition {
        guard event.matchesConstraintKind, var record = constraintsByID[id] else {
            return .ignored
        }

        switch event.phase {
        case .activated:
            guard record.lifecycle != .active else { return .ignored }
            record.lifecycle = .active
            constraintsByID[id] = record
            return .activated(id)
        case .deactivated:
            switch record.lifetime {
            case .oneShot:
                guard let removed = removeRecord(id) else { return .ignored }
                removed.constraint.destroy()
                return .defunctOneShot(id)
            case .persistent:
                record.lifecycle = .inactivePersistent
                constraintsByID[id] = record
                return .inactivePersistent(id)
            }
        }
    }

    private mutating func destroyAndRemoveConstraints(_ ids: [PointerConstraintID]) {
        for id in ids {
            removeRecord(id)?.constraint.destroy()
        }
    }

    private mutating func removeRecord(_ id: PointerConstraintID) -> PointerConstraintRecord? {
        guard let record = constraintsByID.removeValue(forKey: id) else { return nil }
        precondition(idByKey.removeValue(forKey: record.key) == id)
        precondition(idByRawIdentity.removeValue(forKey: record.constraint.rawIdentity) == id)
        preconditionIndicesMatchRecords()
        return record
    }

    private func preconditionIndicesMatchRecords() {
        precondition(constraintsByID.count == idByKey.count)
        precondition(constraintsByID.count == idByRawIdentity.count)
        precondition(
            constraintsByID.allSatisfy { id, record in
                idByKey[record.key] == id
                    && idByRawIdentity[record.constraint.rawIdentity] == id
            }
        )
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

package enum PointerConstraintEventPhase {
    case activated
    case deactivated
}

package enum PointerConstraintProtocolEvent: Equatable, Sendable {
    case locked(PointerConstraintID)
    case unlocked(PointerConstraintID)
    case confined(PointerConstraintID)
    case unconfined(PointerConstraintID)
}

extension RawPointerConstraintEvent {
    package var identity: RawPointerConstraintIdentity {
        switch self {
        case .locked(let identity, _),
            .unlocked(let identity, _),
            .confined(let identity, _),
            .unconfined(let identity, _):
            identity
        }
    }
}

extension PointerConstraintProtocolEvent {
    package var constraintID: PointerConstraintID {
        switch self {
        case .locked(let id), .unlocked(let id), .confined(let id), .unconfined(let id):
            id
        }
    }

    package var phase: PointerConstraintEventPhase {
        switch self {
        case .locked, .confined:
            .activated
        case .unlocked, .unconfined:
            .deactivated
        }
    }

    package var matchesConstraintKind: Bool {
        switch self {
        case .locked(let id), .unlocked(let id):
            id.kind == .locked
        case .confined(let id), .unconfined(let id):
            id.kind == .confined
        }
    }

    package init(_ raw: RawPointerConstraintEvent, id: PointerConstraintID) {
        switch raw {
        case .locked:
            self = .locked(id)
        case .unlocked:
            self = .unlocked(id)
        case .confined:
            self = .confined(id)
        case .unconfined:
            self = .unconfined(id)
        }
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
