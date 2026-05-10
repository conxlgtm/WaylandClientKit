import WaylandRaw

extension DisplayEvent {
    package init(_ raw: RawOutputEvent) {
        switch raw {
        case .changed(let snapshot):
            self = .outputChanged(OutputSnapshot(snapshot))
        case .removed(let id):
            self = .outputRemoved(OutputID(rawValue: id.rawValue))
        }
    }
}
