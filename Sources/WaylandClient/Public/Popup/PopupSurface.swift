public struct PopupSurface: Sendable, Hashable, Identifiable {
    package let popupID: PopupID
    public let id: PopupSurfaceIdentity
    public let parentWindowID: WindowID

    private let display: WaylandDisplay
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

    public func show(
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.showPopup(popupID, timeoutMilliseconds: timeoutMilliseconds, draw)
    }

    public func redraw(
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.redrawPopup(popupID, draw)
    }

    public func requestRedraw() async throws {
        try await display.requestPopupRedraw(popupID)
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
