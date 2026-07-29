import WaylandRaw

final class SurfaceOwnedResourceLedger<Identity: Hashable, Resource> {
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

    func take(
        _ identity: Identity,
        matching predicate: (Resource) -> Bool
    ) -> Resource? {
        guard let resource = resources[identity], predicate(resource) else { return nil }
        return resources.removeValue(forKey: identity)
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

final class SurfacePresentationFeedbackCoordinator {
    private var identities = IDGenerator<SurfacePresentationIdentity>()
    private let resources = SurfaceOwnedResourceLedger<
        SurfacePresentationIdentity,
        RawPresentationFeedback
    > { $0.cancel() }

    func request(
        presentation: RawPresentation,
        surface: RawSurface,
        outputIDForPresentationSyncOutput:
            @escaping (RawOutputPointerIdentity) throws -> OutputID?,
        onFeedback: @escaping (SurfacePresentationFeedback) -> Void,
        onFailure: @escaping (any Error) -> Void
    ) throws -> SurfacePresentationIdentity {
        let identity = identities.next()
        let feedback = try presentation.requestFeedback(for: surface) { [weak self] rawEvent in
            self?.complete(
                identity,
                event: rawEvent,
                outputIDForPresentationSyncOutput: outputIDForPresentationSyncOutput,
                onFeedback: onFeedback,
                onFailure: onFailure
            )
        }
        _ = resources.insert(feedback, for: identity)
        return identity
    }

    func cancel(_ identity: SurfacePresentationIdentity) {
        resources.retire(identity)
    }

    func close() {
        resources.close()
    }

    private func complete(
        _ identity: SurfacePresentationIdentity,
        event rawEvent: RawPresentationFeedbackEvent,
        outputIDForPresentationSyncOutput: (RawOutputPointerIdentity) throws -> OutputID?,
        onFeedback: (SurfacePresentationFeedback) -> Void,
        onFailure: (any Error) -> Void
    ) {
        _ = resources.take(identity)

        do {
            switch rawEvent {
            case .presented(let rawPresented):
                let synchronizedOutput = try rawPresented.synchronizedOutput.flatMap { output in
                    try outputIDForPresentationSyncOutput(output)
                }
                onFeedback(
                    .presented(
                        PresentationFeedback(
                            surface: identity,
                            timestamp: PresentationTimestamp(
                                seconds: rawPresented.timestamp.seconds,
                                nanoseconds: rawPresented.timestamp.nanoseconds
                            ),
                            refreshNanoseconds: rawPresented.refreshNanoseconds == 0
                                ? nil
                                : rawPresented.refreshNanoseconds,
                            sequence: PresentationSequence(value: rawPresented.sequence.value),
                            flags: PresentationFeedbackFlags(rawValue: rawPresented.flags),
                            synchronizedOutput: synchronizedOutput
                        )
                    )
                )
            case .discarded:
                onFeedback(.discarded(identity))
            }
        } catch {
            onFailure(error)
        }
    }
}

final class SoftwareSurfaceReservationCoordinator<PendingReservation> {
    private var identities = IDGenerator<SoftwareFrameReservationToken>()
    private let reservation: (PendingReservation) -> SoftwareFrameReservation
    private let resources:
        SurfaceOwnedResourceLedger<
            SoftwareFrameReservationToken,
            PendingReservation
        >

    init(
        reservation reservationForResource:
            @escaping (PendingReservation) -> SoftwareFrameReservation,
        retire: @escaping (PendingReservation) -> Void
    ) {
        reservation = reservationForResource
        resources = SurfaceOwnedResourceLedger(retireResource: retire)
    }

    func allocateIdentity() -> SoftwareFrameReservationToken {
        identities.next()
    }

    func register(
        _ pendingReservation: PendingReservation,
        for identity: SoftwareFrameReservationToken
    ) {
        _ = resources.insert(pendingReservation, for: identity)
    }

    func take(_ expectedReservation: SoftwareFrameReservation) -> PendingReservation? {
        resources.take(expectedReservation.reservationID) { pendingReservation in
            reservation(pendingReservation) == expectedReservation
        }
    }

    func cancel(_ reservation: SoftwareFrameReservation) -> PendingReservation? {
        take(reservation)
    }

    func close() {
        resources.close()
    }
}
