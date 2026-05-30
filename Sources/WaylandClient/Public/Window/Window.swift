// swiftlint:disable:next type_body_length
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

    public func show(
        damage: SurfaceDamageRegion?,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultConfigureTimeoutMilliseconds,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.showWindow(
            id,
            timeoutMilliseconds: timeoutMilliseconds,
            metadata: .default,
            requestPresentationFeedback: false,
            damage: damage,
            draw
        )
    }

    package func show(
        timeoutMilliseconds: Int32,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion? = nil,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.showWindow(
            id,
            timeoutMilliseconds: timeoutMilliseconds,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            damage: damage,
            draw
        )
    }

    public func redraw(
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.redraw(id, draw)
    }

    public func redraw(
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.redraw(
            id,
            metadata: .default,
            requestPresentationFeedback: false,
            damage: damage,
            draw
        )
    }

    package func redraw(
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion? = nil,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        try await display.redraw(
            id,
            metadata: metadata,
            requestPresentationFeedback: requestPresentationFeedback,
            damage: damage,
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

    public func createSubsurface(
        configuration subsurfaceConfiguration: SubsurfaceConfiguration = .init()
    ) async throws -> Subsurface {
        try await display.createSubsurface(
            parent: self,
            configuration: subsurfaceConfiguration
        )
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

    public func setInputRegion(_ region: SurfaceRegion?) async throws {
        try await display.setWindowInputRegion(id, region)
    }

    public func setOpaqueRegion(_ region: SurfaceRegion?) async throws {
        try await display.setWindowOpaqueRegion(id, region)
    }

    public func requestActivationToken(
        appID: String? = nil,
        serialContext: ActivationSerialContext? = nil,
        timeoutMilliseconds: Int32 = WaylandDisplay.defaultActivationTokenTimeoutMilliseconds
    ) async throws -> ActivationToken {
        try await display.requestActivationToken(
            try ActivationTokenRequest(
                validatingAppID: appID,
                window: self,
                serialContext: serialContext
            ),
            timeoutMilliseconds: timeoutMilliseconds
        )
    }

    public func activate(using token: ActivationToken) async throws {
        try await display.activate(window: self, token: token)
    }

    public func relativePointer(seatID: SeatID) async throws -> RelativePointerSubscription {
        try await display.relativePointer(seatID: seatID)
    }

    public func lockPointer(
        seatID: SeatID,
        cursorHint: PointerLocation? = nil,
        region: PointerConstraintRegion? = nil,
        lifetime: PointerConstraintLifetime = .oneShot
    ) async throws -> PointerConstraint {
        try await display.lockPointer(
            window: self,
            seatID: seatID,
            cursorHint: cursorHint,
            region: region,
            lifetime: lifetime
        )
    }

    public func confinePointer(
        seatID: SeatID,
        region: PointerConstraintRegion? = nil,
        lifetime: PointerConstraintLifetime = .oneShot
    ) async throws -> PointerConstraint {
        try await display.confinePointer(
            window: self,
            seatID: seatID,
            region: region,
            lifetime: lifetime
        )
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
