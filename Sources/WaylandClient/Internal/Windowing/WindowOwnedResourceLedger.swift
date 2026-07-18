import WaylandRaw

final class WindowOwnedResourceLedger<Identity: Hashable, Resource> {
    private var resources: [Identity: Resource] = [:]
    private var isClosed = false
    private let retireResource: (Resource) -> Void

    init(retireResource: @escaping (Resource) -> Void) {
        self.retireResource = retireResource
    }

    var count: Int { resources.count }
    var isEmpty: Bool { resources.isEmpty }

    @discardableResult
    func insert(_ resource: Resource, for identity: Identity) -> Bool {
        guard !isClosed, resources[identity] == nil else {
            retireResource(resource)
            return false
        }
        resources[identity] = resource
        return true
    }

    func take(_ identity: Identity) -> Resource? {
        resources.removeValue(forKey: identity)
    }

    func retire(_ identity: Identity) {
        guard let resource = resources.removeValue(forKey: identity) else { return }
        retireResource(resource)
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        let removed = resources
        resources.removeAll()
        for identity in removed.keys.sorted(by: stableIdentityOrder) {
            guard let resource = removed[identity] else { continue }
            retireResource(resource)
        }
    }

    private func stableIdentityOrder(_ lhs: Identity, _ rhs: Identity) -> Bool {
        String(reflecting: lhs) < String(reflecting: rhs)
    }
}

final class WindowPresentationFeedbackCoordinator {
    private var identities = IDGenerator<SurfacePresentationIdentity>()
    private let resources = WindowOwnedResourceLedger<
        SurfacePresentationIdentity,
        RawPresentationFeedback
    > { $0.cancel() }

    func allocateIdentity() -> SurfacePresentationIdentity {
        identities.next()
    }

    func register(_ feedback: RawPresentationFeedback, for identity: SurfacePresentationIdentity) {
        _ = resources.insert(feedback, for: identity)
    }

    func complete(_ identity: SurfacePresentationIdentity) {
        _ = resources.take(identity)
    }

    func cancel(_ identity: SurfacePresentationIdentity) {
        resources.retire(identity)
    }

    func close() {
        resources.close()
    }
}

final class WindowSoftwareReservationCoordinator {
    private var identities = IDGenerator<SoftwareFrameReservationToken>()
    private let resources = WindowOwnedResourceLedger<
        SoftwareFrameReservationToken,
        PendingSoftwareFrameReservation
    > { $0.reservedFrame.drawingBuffer.discard() }

    func allocateIdentity() -> SoftwareFrameReservationToken {
        identities.next()
    }

    func register(
        _ reservation: PendingSoftwareFrameReservation,
        for identity: SoftwareFrameReservationToken
    ) {
        _ = resources.insert(reservation, for: identity)
    }

    func take(_ identity: SoftwareFrameReservationToken) -> PendingSoftwareFrameReservation? {
        resources.take(identity)
    }

    func cancel(_ identity: SoftwareFrameReservationToken) -> Bool {
        guard let reservation = resources.take(identity) else { return false }
        reservation.reservedFrame.drawingBuffer.discard()
        return true
    }

    func close() {
        resources.close()
    }
}
