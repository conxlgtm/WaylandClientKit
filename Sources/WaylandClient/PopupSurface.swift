package struct PopupSurface: Sendable, Hashable {
    package let id: PopupID
    package let parentWindowID: WindowID

    private let display: WaylandDisplay
    private let displayIdentity: ObjectIdentifier

    package init(
        id popupID: PopupID,
        parentWindowID popupParentWindowID: WindowID,
        display owningDisplay: WaylandDisplay
    ) {
        id = popupID
        parentWindowID = popupParentWindowID
        display = owningDisplay
        displayIdentity = ObjectIdentifier(owningDisplay)
    }

    package static func == (lhs: PopupSurface, rhs: PopupSurface) -> Bool {
        lhs.id == rhs.id && lhs.displayIdentity == rhs.displayIdentity
    }

    package func hash(into hasher: inout Hasher) {
        hasher.combine(displayIdentity)
        hasher.combine(id)
    }
}
