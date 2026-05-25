public struct Window: Sendable, Hashable {
    public let id: WindowID
    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<WindowID>

    package init(id windowID: WindowID, display owningDisplay: WaylandDisplay) {
        id = windowID
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: windowID, display: owningDisplay)
    }

    package func isOwned(by owningDisplay: WaylandDisplay) -> Bool {
        ownership.isOwned(by: owningDisplay)
    }

    public func show(
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.showWindow(id, timeoutMilliseconds: timeoutMilliseconds, draw)
    }

    package func show(
        timeoutMilliseconds: Int32,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.showWindow(
            id,
            timeoutMilliseconds: timeoutMilliseconds,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            draw
        )
    }

    public func redraw(
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.redraw(id, draw)
    }

    package func redraw(
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.redraw(
            id,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            draw
        )
    }

    public func close() async {
        await display.closeWindow(id)
    }

    public func createPopup(configuration popupConfiguration: PopupConfiguration) async throws
        -> PopupSurface
    {
        try await display.createPopup(parent: self, configuration: popupConfiguration)
    }

    public func requestRedraw() async throws {
        try await display.requestRedraw(id)
    }

    public var presentationEvents: WindowPresentationEvents {
        display.windowPresentationEvents(for: id)
    }

    public func requestPresentationFeedback() async throws {
        try await display.requestPresentationFeedback(id)
    }

    public func requestActivationToken(
        appID: String? = nil,
        seatID: SeatID? = nil,
        serial: InputSerial? = nil,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultActivationTokenTimeoutMilliseconds
    ) async throws -> ActivationToken {
        try await display.requestActivationToken(
            ActivationTokenRequest(
                appID: appID,
                window: self,
                seatID: seatID,
                serial: serial
            ),
            timeoutMilliseconds: timeoutMilliseconds
        )
    }

    public func activate(using token: ActivationToken) async throws {
        try await display.activate(window: self, token: token)
    }

    public func setTitle(_ title: WaylandString) async throws {
        try await display.setWindowTitle(id, title)
    }

    public func setTitle(_ title: String) async throws {
        try await setTitle(try WaylandString(title))
    }

    public func setAppID(_ appID: NonEmptyWaylandString) async throws {
        try await display.setWindowAppID(id, appID)
    }

    public func setAppID(_ appID: String) async throws {
        try await setAppID(try NonEmptyWaylandString(appID))
    }

    public func setMinimumSize(_ size: PositiveLogicalSize?) async throws {
        try await display.setWindowMinimumSize(id, size)
    }

    public func setMaximumSize(_ size: PositiveLogicalSize?) async throws {
        try await display.setWindowMaximumSize(id, size)
    }

    public func requestMaximize() async throws {
        try await display.requestWindowMaximize(id)
    }

    public func requestUnmaximize() async throws {
        try await display.requestWindowUnmaximize(id)
    }

    public func requestFullscreen(output: OutputID? = nil) async throws {
        try await display.requestWindowFullscreen(id, output: output)
    }

    public func requestExitFullscreen() async throws {
        try await display.requestWindowExitFullscreen(id)
    }

    public func requestMinimize() async throws {
        try await display.requestWindowMinimize(id)
    }

    public func requestInteractiveMove(seatID: SeatID, serial: InputSerial) async throws {
        try await display.requestWindowInteractiveMove(id, seatID: seatID, serial: serial)
    }

    public func requestInteractiveResize(
        seatID: SeatID,
        serial: InputSerial,
        edge: WindowResizeEdge
    ) async throws {
        try await display.requestWindowInteractiveResize(
            id,
            seatID: seatID,
            serial: serial,
            edge: edge
        )
    }

    public func requestWindowMenu(
        seatID: SeatID,
        serial: InputSerial,
        position: LogicalOffset
    ) async throws {
        try await display.requestWindowMenu(
            id,
            seatID: seatID,
            serial: serial,
            position: position
        )
    }

    public func startDrag(
        source configuration: DragSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial,
        icon: DragIcon = .none
    ) async throws -> DragSource {
        try await display.startDrag(
            from: id,
            source: configuration,
            seatID: seatID,
            serial: serial,
            icon: icon
        )
    }

    public var isClosed: Bool {
        get async throws {
            try await display.windowIsClosed(id)
        }
    }

    public var needsRedraw: Bool {
        get async throws {
            try await display.windowNeedsRedraw(id)
        }
    }

    public var decorationMode: WindowDecorationMode {
        get async throws {
            try await display.windowDecorationMode(id)
        }
    }

    public var geometry: SurfaceGeometry {
        get async throws {
            try await display.windowGeometry(id)
        }
    }

    public var stateSnapshot: WindowStateSnapshot {
        get async throws {
            try await display.windowStateSnapshot(id)
        }
    }

    public static func == (lhs: Window, rhs: Window) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}
