public struct PopupSurface: Sendable, Hashable {
    package let id: PopupID
    public let parentWindowID: WindowID

    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<PopupID>

    package init(
        id popupID: PopupID,
        parentWindowID popupParentWindowID: WindowID,
        display owningDisplay: WaylandDisplay
    ) {
        id = popupID
        parentWindowID = popupParentWindowID
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: popupID, display: owningDisplay)
    }

    public var identity: PopupSurfaceIdentity {
        PopupSurfaceIdentity(id)
    }

    public func show(
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.showPopup(id, timeoutMilliseconds: timeoutMilliseconds, draw)
    }

    public func redraw(
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.redrawPopup(id, draw)
    }

    public func requestRedraw() async throws {
        try await display.requestPopupRedraw(id)
    }

    public func close() async {
        await display.closePopup(id)
    }

    public var isClosed: Bool {
        get async throws {
            try await display.popupIsClosed(id)
        }
    }

    public var needsRedraw: Bool {
        get async throws {
            try await display.popupNeedsRedraw(id)
        }
    }

    public var geometry: SurfaceGeometry {
        get async throws {
            try await display.popupGeometry(id)
        }
    }

    public var placement: PopupPlacement {
        get async throws {
            try await display.popupPlacement(id)
        }
    }

    public static func == (lhs: PopupSurface, rhs: PopupSurface) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}
