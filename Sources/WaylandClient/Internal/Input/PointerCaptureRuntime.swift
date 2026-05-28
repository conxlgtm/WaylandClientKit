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

package struct ManagedPointerConstraintState {
    package let seatID: SeatID
    package let surfaceID: RawObjectID
    package let constraint: ManagedPointerConstraint
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

package struct PointerConstraintRegistryEntry: Equatable, Sendable {
    package let key: PointerConstraintKey
    package let lifetime: PointerConstraintLifetime
    package var lifecycle: PointerConstraintLifecycle
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

package enum PointerConstraintRuntimeEffect: Equatable, Sendable {
    case destroyOneShotConstraint(PointerConstraintID)
}

package struct PointerConstraintRuntimeResult: Equatable, Sendable {
    package let transition: PointerConstraintLifecycleTransition
    package let lifecycleEvent: PointerConstraintLifecycleEvent?
    package let effects: [PointerConstraintRuntimeEffect]

    package init(_ constraintTransition: PointerConstraintLifecycleTransition) {
        transition = constraintTransition
        lifecycleEvent = constraintTransition.lifecycleEvent
        switch constraintTransition {
        case .defunctOneShot(let id):
            effects = [.destroyOneShotConstraint(id)]
        case .activated, .inactivePersistent, .ignored:
            effects = []
        }
    }
}

package struct PointerConstraintRuntime {
    private var constraints: [PointerConstraintID: ManagedPointerConstraintState] = [:]
    private var idByRawIdentity: [RawPointerConstraintIdentity: PointerConstraintID] = [:]
    private var registry = PointerConstraintRegistry()

    package init() {
        // Exposes the synthesized initializer at package scope.
    }

    package func preflight(surfaceID: RawObjectID, seatID: SeatID) throws {
        try registry.preflight(surfaceID: surfaceID, seatID: seatID)
    }

    package mutating func insert(
        id: PointerConstraintID,
        seatID: SeatID,
        surfaceID: RawObjectID,
        constraint: ManagedPointerConstraint,
        lifetime: PointerConstraintLifetime
    ) {
        constraints[id] = ManagedPointerConstraintState(
            seatID: seatID,
            surfaceID: surfaceID,
            constraint: constraint
        )
        idByRawIdentity[constraint.rawIdentity] = id
        registry.insert(
            id: id,
            surfaceID: surfaceID,
            seatID: seatID,
            lifetime: lifetime
        )
    }

    package mutating func destroyPointerConstraint(_ id: PointerConstraintID) throws {
        guard let state = constraints.removeValue(forKey: id) else {
            throw PointerCaptureError.unknownPointerConstraint(id)
        }

        _ = registry.remove(id)
        idByRawIdentity.removeValue(forKey: state.constraint.rawIdentity)
        state.constraint.destroy()
    }

    package mutating func processRawInputEvent(
        _ event: RawInputEvent
    ) -> PointerConstraintLifecycleEvent? {
        guard case .pointer(.constraint(let constraintEvent)) = event.kind else { return nil }
        guard let id = idByRawIdentity[constraintEvent.identity] else { return nil }

        let transition = registry.transition(
            PointerConstraintProtocolEvent(constraintEvent, id: id)
        )
        let result = PointerConstraintRuntimeResult(transition)
        interpret(result.effects)
        return result.lifecycleEvent
    }

    package mutating func removeSeat(_ seatID: SeatID) {
        let constraintIDs = constraints.filter { $0.value.seatID == seatID }.map(\.key)
        destroyAndRemoveConstraints(constraintIDs)
    }

    package mutating func removeSurface(_ surfaceID: RawObjectID) {
        let constraintIDs = constraints.filter { $0.value.surfaceID == surfaceID }.map(\.key)
        destroyAndRemoveConstraints(constraintIDs)
    }

    package mutating func removeAll() {
        for pointerConstraint in constraints.values {
            pointerConstraint.constraint.destroy()
        }
        constraints.removeAll()
        idByRawIdentity.removeAll()
        registry.removeAll()
    }

    package func lifecycle(for id: PointerConstraintID) -> PointerConstraintLifecycle? {
        registry.lifecycle(for: id)
    }

    private mutating func interpret(_ effects: [PointerConstraintRuntimeEffect]) {
        for effect in effects {
            switch effect {
            case .destroyOneShotConstraint(let id):
                guard let state = constraints.removeValue(forKey: id) else { continue }
                idByRawIdentity.removeValue(forKey: state.constraint.rawIdentity)
                state.constraint.destroy()
            }
        }
    }

    private mutating func destroyAndRemoveConstraints(_ ids: [PointerConstraintID]) {
        for id in ids {
            _ = registry.remove(id)
            guard let state = constraints.removeValue(forKey: id) else { continue }
            idByRawIdentity.removeValue(forKey: state.constraint.rawIdentity)
            state.constraint.destroy()
        }
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
    private var entryByID: [PointerConstraintID: PointerConstraintRegistryEntry] = [:]
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
        seatID: SeatID,
        lifetime: PointerConstraintLifetime
    ) {
        let key = PointerConstraintKey(surfaceID: surfaceID, seatID: seatID)
        entryByID[id] = PointerConstraintRegistryEntry(
            key: key,
            lifetime: lifetime,
            lifecycle: .requested
        )
        idByKey[key] = id
    }

    @discardableResult
    package mutating func remove(_ id: PointerConstraintID) -> PointerConstraintKey? {
        guard let key = entryByID.removeValue(forKey: id)?.key else { return nil }
        idByKey.removeValue(forKey: key)
        return key
    }

    package func lifecycle(for id: PointerConstraintID) -> PointerConstraintLifecycle? {
        entryByID[id]?.lifecycle
    }

    @discardableResult
    package mutating func transition(
        _ event: PointerConstraintProtocolEvent
    ) -> PointerConstraintLifecycleTransition {
        let id = event.constraintID
        guard
            event.matchesConstraintKind,
            var entry = entryByID[id]
        else {
            return .ignored
        }

        switch event.phase {
        case .activated:
            guard entry.lifecycle != .active else { return .ignored }

            entry.lifecycle = .active
            entryByID[id] = entry
            return .activated(id)
        case .deactivated:
            switch entry.lifetime {
            case .oneShot:
                remove(id)
                return .defunctOneShot(id)
            case .persistent:
                entry.lifecycle = .inactivePersistent
                entryByID[id] = entry
                return .inactivePersistent(id)
            }
        }
    }

    package mutating func removeAll() {
        entryByID.removeAll()
        idByKey.removeAll()
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
