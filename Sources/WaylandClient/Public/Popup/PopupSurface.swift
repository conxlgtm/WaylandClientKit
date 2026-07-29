public struct PopupSurface: Sendable, Hashable, Identifiable {
    package let popupID: PopupID
    public let id: PopupSurfaceIdentity
    public let parentWindowID: WindowID

    package let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<PopupID>

    package init(
        id popupID: PopupID,
        parentWindowID popupParentWindowID: WindowID,
        display owningDisplay: WaylandDisplay
    ) {
        self.popupID = popupID
        id = PopupSurfaceIdentity(popupID)
        parentWindowID = popupParentWindowID
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: popupID, display: owningDisplay)
    }

    public var identity: PopupSurfaceIdentity {
        id
    }

    public func requestRedraw() async throws {
        try await display.requestPopupRedraw(popupID)
    }

    public var presentationEvents: ManagedSurfacePresentationEvents {
        display.managedSurfacePresentationEvents(for: .popup(id))
    }

    public func setInputRegion(_ region: SurfaceRegion?) async throws {
        try await display.setPopupInputRegion(popupID, region)
    }

    public func setOpaqueRegion(_ region: SurfaceRegion?) async throws {
        try await display.setPopupOpaqueRegion(popupID, region)
    }

    public func close() async {
        await display.closePopup(popupID)
    }

    public var isClosed: Bool {
        get async throws {
            try await display.popupIsClosed(popupID)
        }
    }

    public var needsRedraw: Bool {
        get async throws {
            try await display.popupNeedsRedraw(popupID)
        }
    }

    public var geometry: SurfaceGeometry {
        get async throws {
            try await display.popupGeometry(popupID)
        }
    }

    public var placement: PopupPlacement {
        get async throws {
            try await display.popupPlacement(popupID)
        }
    }

    public static func == (lhs: PopupSurface, rhs: PopupSurface) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}
