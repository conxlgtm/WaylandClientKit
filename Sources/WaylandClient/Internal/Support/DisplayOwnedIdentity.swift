package struct DisplayOwnedIdentity<ID: Hashable & Sendable>: Hashable, Sendable {
    package let id: ID
    package let displayIdentity: ObjectIdentifier

    package init(id ownedID: ID, display owningDisplay: WaylandDisplay) {
        id = ownedID
        displayIdentity = ObjectIdentifier(owningDisplay)
    }

    package init(id ownedID: ID, displayIdentity owningDisplayIdentity: ObjectIdentifier) {
        id = ownedID
        displayIdentity = owningDisplayIdentity
    }

    package func isOwned(by display: WaylandDisplay) -> Bool {
        displayIdentity == ObjectIdentifier(display)
    }

    package func isOwned(byDisplayIdentity candidateIdentity: ObjectIdentifier) -> Bool {
        displayIdentity == candidateIdentity
    }
}
