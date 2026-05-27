import WaylandRaw

package struct ManagedPointerConstraint {
    private let destroyImplementation: () -> Void

    package let id: PointerConstraintID

    package init(id constraintID: PointerConstraintID, destroy: @escaping () -> Void) {
        id = constraintID
        destroyImplementation = destroy
    }

    package static func locked(
        _ pointer: RawLockedPointer,
        region: RawRegion?
    ) -> ManagedPointerConstraint {
        ManagedPointerConstraint(id: PointerConstraintID(pointer.identity)) {
            pointer.destroy()
            region?.destroy()
        }
    }

    package static func confined(
        _ pointer: RawConfinedPointer,
        region: RawRegion?
    ) -> ManagedPointerConstraint {
        ManagedPointerConstraint(id: PointerConstraintID(pointer.identity)) {
            pointer.destroy()
            region?.destroy()
        }
    }

    package func destroy() {
        destroyImplementation()
    }
}

package struct ManagedPointerConstraintState {
    let seatID: SeatID
    let surfaceID: RawObjectID
    let constraint: ManagedPointerConstraint
}

package final class PointerCaptureManager {
    private let connection: RawDisplayConnection
    private var nextRelativePointerSubscriptionID: UInt64 = 1
    private var relativePointers:
        [RelativePointerSubscriptionID: (seatID: SeatID, pointer: RawRelativePointer)] = [:]
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

        if let fixedCursorHint {
            constraint.pointer.setCursorPositionHint(
                x: fixedCursorHint.x,
                y: fixedCursorHint.y
            )
            surface.commit()
        }

        let managed = ManagedPointerConstraint.locked(
            constraint.pointer,
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

        let managed = ManagedPointerConstraint.confined(
            constraint.pointer,
            region: constraint.region
        )
        return storeConstraint(
            managed,
            seatID: seatID,
            surfaceID: surface.objectID,
            lifetime: lifetime
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
        let relativeIDs = relativePointers.filter { $0.value.seatID == seatID }.map(\.key)
        for id in relativeIDs {
            _ = relativePointerRegistry.remove(id)
            relativePointers.removeValue(forKey: id)?.pointer.destroy()
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
        for relativePointer in relativePointers.values {
            relativePointer.pointer.destroy()
        }
        relativePointers.removeAll()
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
        registry.insert(
            id: id,
            surfaceID: surfaceID,
            seatID: seatID,
            lifetime: lifetime
        )
    }

    package mutating func destroyPointerConstraint(_ id: PointerConstraintID) throws {
        guard let constraint = constraints.removeValue(forKey: id)?.constraint else {
            throw PointerCaptureError.unknownPointerConstraint(id)
        }

        _ = registry.remove(id)
        constraint.destroy()
    }

    package mutating func processRawInputEvent(
        _ event: RawInputEvent
    ) -> PointerConstraintLifecycleEvent? {
        guard case .pointer(.constraint(let constraintEvent)) = event.kind else { return nil }

        let transition = registry.transition(
            PointerConstraintProtocolEvent(constraintEvent)
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
        registry.removeAll()
    }

    package func lifecycle(for id: PointerConstraintID) -> PointerConstraintLifecycle? {
        registry.lifecycle(for: id)
    }

    private mutating func interpret(_ effects: [PointerConstraintRuntimeEffect]) {
        for effect in effects {
            switch effect {
            case .destroyOneShotConstraint(let id):
                constraints.removeValue(forKey: id)?.constraint.destroy()
            }
        }
    }

    private mutating func destroyAndRemoveConstraints(_ ids: [PointerConstraintID]) {
        for id in ids {
            _ = registry.remove(id)
            constraints.removeValue(forKey: id)?.constraint.destroy()
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

private enum PointerConstraintEventPhase {
    case activated
    case deactivated
}

package enum PointerConstraintProtocolEvent: Equatable, Sendable {
    case locked(PointerConstraintID)
    case unlocked(PointerConstraintID)
    case confined(PointerConstraintID)
    case unconfined(PointerConstraintID)
}

extension PointerConstraintProtocolEvent {
    fileprivate var constraintID: PointerConstraintID {
        switch self {
        case .locked(let id), .unlocked(let id), .confined(let id), .unconfined(let id):
            id
        }
    }

    fileprivate var phase: PointerConstraintEventPhase {
        switch self {
        case .locked, .confined:
            .activated
        case .unlocked, .unconfined:
            .deactivated
        }
    }

    fileprivate var matchesConstraintKind: Bool {
        switch self {
        case .locked(let id), .unlocked(let id):
            id.kind == .locked
        case .confined(let id), .unconfined(let id):
            id.kind == .confined
        }
    }

    package init(_ raw: RawPointerConstraintEvent) {
        switch raw {
        case .locked(let identity, _):
            self = .locked(PointerConstraintID(identity))
        case .unlocked(let identity, _):
            self = .unlocked(PointerConstraintID(identity))
        case .confined(let identity, _):
            self = .confined(PointerConstraintID(identity))
        case .unconfined(let identity, _):
            self = .unconfined(PointerConstraintID(identity))
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
