import WaylandRaw

extension DisplayCore {
    func foreignToplevelListSnapshot(
        timeoutMilliseconds: Int32
    ) throws -> ForeignToplevelListSnapshot {
        try withFatalFailureFinalization {
            let session = try requireSession()
            let collector = ForeignToplevelListCollector(core: self)
            guard
                let list = try session.connection.bindForeignToplevelListOneShot(
                    onEvent: collector.handle
                )
            else {
                throw ClientError.display(.foreignToplevelListUnavailable)
            }
            defer { list.destroy() }

            try session.connection.completeInitialDiscovery(
                timeoutMilliseconds: timeoutMilliseconds
            )
            list.stop()
            return collector.snapshot()
        }
    }

    func foreignToplevelID(for identifier: String?) -> ForeignToplevelID {
        guard let identifier else {
            return foreignToplevelIDs.next()
        }

        if let existing = foreignToplevelIDsByProtocolIdentifier[identifier] {
            return existing
        }

        let id = foreignToplevelIDs.next()
        foreignToplevelIDsByProtocolIdentifier[identifier] = id
        return id
    }
}

private final class ForeignToplevelListCollector {
    private struct Draft {
        var id: ForeignToplevelID?
        var identifier: String?
        var title: String?
        var appID: String?
        var hasEmitted = false
    }

    private unowned let core: DisplayCore
    private var drafts: [ObjectIdentifier: Draft] = [:]
    private var snapshots: [ForeignToplevelID: ForeignToplevelSnapshot] = [:]
    private var events: [ForeignToplevelEvent] = []

    init(core displayCore: DisplayCore) {
        core = displayCore
    }

    func handle(_ event: RawForeignToplevelListEvent) {
        switch event {
        case .toplevel(let handle):
            drafts[ObjectIdentifier(handle)] = Draft()
        case .handle(let handle, let handleEvent):
            self.handle(handleEvent, for: ObjectIdentifier(handle))
        case .finished:
            break
        }
    }

    private func handle(
        _ event: RawForeignToplevelHandleEvent,
        for key: ObjectIdentifier
    ) {
        guard var draft = drafts[key] else { return }

        switch event {
        case .identifier(let identifier):
            draft.identifier = identifier
            drafts[key] = draft
        case .title(let title):
            draft.title = title
            drafts[key] = draft
        case .appID(let appID):
            draft.appID = appID
            drafts[key] = draft
        case .done:
            publish(draft, for: key)
        case .closed:
            remove(draft, for: key)
        }
    }

    private func publish(_ draft: Draft, for key: ObjectIdentifier) {
        var nextDraft = draft
        let id = draft.id ?? core.foreignToplevelID(for: draft.identifier)
        nextDraft.id = id
        nextDraft.hasEmitted = true
        drafts[key] = nextDraft

        let snapshot = ForeignToplevelSnapshot(
            id: id,
            protocolIdentifier: draft.identifier,
            title: draft.title,
            appID: draft.appID
        )
        snapshots[id] = snapshot
        events.append(draft.hasEmitted ? .updated(snapshot) : .added(snapshot))
    }

    private func remove(_ draft: Draft, for key: ObjectIdentifier) {
        drafts.removeValue(forKey: key)
        guard let id = draft.id else { return }

        snapshots.removeValue(forKey: id)
        events.append(.removed(id))
    }

    func snapshot() -> ForeignToplevelListSnapshot {
        ForeignToplevelListSnapshot(
            toplevels: snapshots.values.sorted { $0.id.rawValue < $1.id.rawValue },
            events: events
        )
    }
}
