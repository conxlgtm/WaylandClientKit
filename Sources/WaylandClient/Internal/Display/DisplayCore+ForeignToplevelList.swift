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

            try session.connection.completeInitialDiscovery(
                timeoutMilliseconds: timeoutMilliseconds
            )
            list.stop()
            try session.connection.completeInitialDiscovery(
                timeoutMilliseconds: timeoutMilliseconds
            )
            guard collector.isFinished else {
                throw ClientError.display(.foreignToplevelListIncomplete)
            }
            list.destroy()
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

final class ForeignToplevelListCollector {
    private struct Draft {
        var id: ForeignToplevelID?
        var identifier: String?
        var title: String?
        var appID: String?
        var hasEmitted = false
    }

    private let idProvider: (String?) -> ForeignToplevelID
    private var drafts: [ObjectIdentifier: Draft] = [:]
    private var snapshots: [ForeignToplevelID: ForeignToplevelSnapshot] = [:]
    private var events: [ForeignToplevelEvent] = []
    private(set) var isFinished = false

    init(core displayCore: DisplayCore) {
        idProvider = { identifier in
            displayCore.foreignToplevelID(for: identifier)
        }
    }

    init(idProvider toplevelIDProvider: @escaping (String?) -> ForeignToplevelID) {
        idProvider = toplevelIDProvider
    }

    func handle(_ event: RawForeignToplevelListEvent) {
        switch event {
        case .toplevel(let handle):
            drafts[ObjectIdentifier(handle)] = Draft()
        case .handle(let handle, let handleEvent):
            self.handle(handleEvent, for: ObjectIdentifier(handle))
        case .finished:
            isFinished = true
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
        let id = draft.id ?? idProvider(draft.identifier)
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
