import WaylandRaw

extension DisplayCore {
    func compositorSessionEvents(
        reason: CompositorSessionReason,
        existingID: CompositorSessionID?,
        timeoutMilliseconds: Int32
    ) throws -> CompositorSessionEventSnapshot {
        try withFatalFailureFinalization {
            let session = try requireSession()
            guard
                let manager = try session.connection.bindCompositorSessionManagerOneShot()
            else {
                throw ClientError.display(.compositorSessionManagementUnavailable)
            }
            defer { manager.destroy() }

            var events: [CompositorSessionEvent] = []
            let rawSession = try manager.getSession(
                reason: reason.rawReason,
                existingID: existingID.map { RawCompositorSessionID($0.value) }
            ) { event in
                events.append(CompositorSessionEvent(event))
            }
            defer { rawSession.destroy() }

            try session.connection.completeInitialDiscovery(
                timeoutMilliseconds: timeoutMilliseconds
            )
            return CompositorSessionEventSnapshot(events: events)
        }
    }
}

extension CompositorSessionEvent {
    init(_ raw: RawCompositorSessionEvent) {
        switch raw {
        case .created(let sessionID):
            self = .created(CompositorSessionID(unchecked: sessionID.value))
        case .restored:
            self = .restored
        case .replaced:
            self = .replaced
        }
    }
}
