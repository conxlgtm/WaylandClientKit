package struct DisplayOwnedIdentity<ID: Hashable & Sendable>: Hashable, Sendable {
    package let id: ID
    package let displayIdentity: ObjectIdentifier

    package init(id ownedID: ID, display owningDisplay: WaylandDisplay) {
        id = ownedID
        displayIdentity = ObjectIdentifier(owningDisplay)
    }

    package func isOwned(by display: WaylandDisplay) -> Bool {
        displayIdentity == ObjectIdentifier(display)
    }
}
