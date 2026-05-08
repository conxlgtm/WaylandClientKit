import WaylandRaw
import WaylandRuntime

public actor WaylandDisplay {
    public static let defaultDiscoveryTimeoutMilliseconds: Int32 = 1_000
    public static let defaultConfigureTimeoutMilliseconds: Int32 = 1_000

    private nonisolated let runtime: WaylandDisplayRuntime
    private var lifecycle = WaylandDisplayLifecycle.initializing

    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        unsafe runtime.executor.asUnownedSerialExecutor()
    }

    public nonisolated var events: DisplayEvents {
        runtime.events
    }

    public nonisolated var inputEvents: InputEvents {
        runtime.inputEvents
    }

    public nonisolated var dataTransferEvents: DataTransferEvents {
        runtime.dataTransferEvents
    }

    public nonisolated var diagnostics: DisplayDiagnostics {
        runtime.diagnostics
    }

    private init(runtime displayRuntime: WaylandDisplayRuntime) {
        runtime = displayRuntime
    }

    isolated deinit {
        runtime.actorDidDeinitialize(lifecycle: &lifecycle)
    }

    private static func openConnection(
        configuration displayConfiguration: DisplayConfiguration,
        cursorConfiguration: CursorConfiguration = .init(),
        discoveryTimeoutMilliseconds: Int32 = defaultDiscoveryTimeoutMilliseconds
    ) async throws -> WaylandDisplay {
        let runtime = try WaylandDisplayRuntime(configuration: displayConfiguration)
        let display = WaylandDisplay(runtime: runtime)
        try await display.initialize(
            cursorConfiguration: cursorConfiguration,
            discoveryTimeoutMilliseconds: discoveryTimeoutMilliseconds,
            configuration: displayConfiguration
        )
        return display
    }

    public static func withConnection<ResultValue: Sendable>(
        configuration displayConfiguration: DisplayConfiguration,
        cursorConfiguration: CursorConfiguration = .init(),
        discoveryTimeoutMilliseconds: Int32 = defaultDiscoveryTimeoutMilliseconds,
        _ body: @Sendable (WaylandDisplay) async throws -> ResultValue
    ) async throws -> ResultValue {
        let display = try await openConnection(
            configuration: displayConfiguration,
            cursorConfiguration: cursorConfiguration,
            discoveryTimeoutMilliseconds: discoveryTimeoutMilliseconds
        )

        do {
            let result = try await body(display)
            await display.close()
            return result
        } catch {
            await display.close()
            throw error
        }
    }

    public static func withConnection<ResultValue: Sendable>(
        cursorConfiguration: CursorConfiguration = .init(),
        discoveryTimeoutMilliseconds: Int32 = defaultDiscoveryTimeoutMilliseconds,
        eventStreamConfiguration: EventStreamConfiguration = .init(),
        _ body: @Sendable (WaylandDisplay) async throws -> ResultValue
    ) async throws -> ResultValue {
        try await withConnection(
            configuration: DisplayConfiguration(eventStreams: eventStreamConfiguration),
            cursorConfiguration: cursorConfiguration,
            discoveryTimeoutMilliseconds: discoveryTimeoutMilliseconds,
            body
        )
    }

    public var isClosed: Bool {
        guard case .active(let core, _) = lifecycle else {
            return true
        }

        return core.isClosed
    }

    public func currentPointerCursor() throws -> PointerCursor {
        try requireCore().currentPointerCursor()
    }

    @discardableResult
    public func setPointerCursor(_ cursor: PointerCursor) throws -> [CursorRequestResult] {
        try requireCore().setPointerCursor(cursor)
    }

    @discardableResult
    public func createTopLevelWindow(
        configuration windowConfiguration: WindowConfiguration = .default
    ) throws -> Window {
        let windowID = try createTopLevelWindowID(configuration: windowConfiguration)
        return Window(id: windowID, display: self)
    }

    @discardableResult
    package func createTopLevelWindowID(
        configuration windowConfiguration: WindowConfiguration = .default
    ) throws -> WindowID {
        try requireCore().createTopLevelWindowID(configuration: windowConfiguration)
    }

    package func createPopup(
        parent window: Window,
        configuration popupConfiguration: PopupConfiguration
    ) throws -> PopupSurface {
        guard window.isOwned(by: self) else {
            throw ClientError.display(.foreignWindow(window.id))
        }

        let popupID = try createPopupID(
            parent: window.id,
            configuration: popupConfiguration
        )
        return PopupSurface(id: popupID, parentWindowID: window.id, display: self)
    }

    @discardableResult
    package func createPopupID(
        parent windowID: WindowID,
        configuration popupConfiguration: PopupConfiguration
    ) throws -> PopupID {
        try requireCore().createPopup(parent: windowID, configuration: popupConfiguration)
    }

    package func showWindow(
        _ windowID: WindowID,
        timeoutMilliseconds: Int32 = defaultConfigureTimeoutMilliseconds,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().showWindow(
            windowID,
            timeoutMilliseconds: timeoutMilliseconds,
            draw
        )
    }

    package func redraw(
        _ windowID: WindowID,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().redraw(windowID, draw)
    }

    package func showPopup(
        _ popupID: PopupID,
        timeoutMilliseconds: Int32 = defaultConfigureTimeoutMilliseconds,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().showPopup(
            popupID,
            timeoutMilliseconds: timeoutMilliseconds,
            draw
        )
    }

    package func redrawPopup(
        _ popupID: PopupID,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().redrawPopup(popupID, draw)
    }

    package func windowIsClosed(_ windowID: WindowID) throws -> Bool {
        try requireCore().windowIsClosed(windowID)
    }

    package func windowNeedsRedraw(_ windowID: WindowID) throws -> Bool {
        try requireCore().windowNeedsRedraw(windowID)
    }

    package func windowDecorationMode(_ windowID: WindowID) throws -> WindowDecorationMode {
        try requireCore().windowDecorationMode(windowID)
    }

    package func windowGeometry(_ windowID: WindowID) throws -> SurfaceGeometry {
        try requireCore().windowGeometry(windowID)
    }

    package func requestRedraw(_ windowID: WindowID) throws {
        try requireCore().requestRedraw(windowID)
    }

    package func popupIsClosed(_ popupID: PopupID) throws -> Bool {
        try requireCore().popupIsClosed(popupID)
    }

    package func popupNeedsRedraw(_ popupID: PopupID) throws -> Bool {
        try requireCore().popupNeedsRedraw(popupID)
    }

    package func popupGeometry(_ popupID: PopupID) throws -> SurfaceGeometry {
        try requireCore().popupGeometry(popupID)
    }

    package func popupPlacement(_ popupID: PopupID) throws -> PopupPlacement {
        try requireCore().popupPlacement(popupID)
    }

    package func requestPopupRedraw(_ popupID: PopupID) throws {
        try requireCore().requestPopupRedraw(popupID)
    }

    package func closeWindow(_ windowID: WindowID) {
        guard case .active(let core, _) = lifecycle else {
            return
        }

        core.closeWindow(windowID)
    }

    package func closePopup(_ popupID: PopupID) {
        guard case .active(let core, _) = lifecycle else {
            return
        }

        core.closePopup(popupID)
    }

    public func close() {
        guard case .active(let activeCore, let activeEventSource) = lifecycle else {
            lifecycle = .closed
            return
        }

        runtime.clearEventSource(activeEventSource)
        activeCore.close()
        lifecycle = .closed
    }

    private func initialize(
        cursorConfiguration: CursorConfiguration,
        discoveryTimeoutMilliseconds: Int32,
        configuration displayConfiguration: DisplayConfiguration
    ) throws {
        precondition(
            lifecycle.isInitializing,
            "WaylandDisplay initialized more than once"
        )
        let invariantFailureSink = RawInvariantFailureSink()
        let connection = try RawDisplayConnection.connect(
            invariantFailureSink: invariantFailureSink,
            inputQueueConfiguration: RawInputQueueConfiguration(
                capacity: RawInputQueueCapacity(
                    unchecked: displayConfiguration.inputPipeline.rawInputQueueCapacity.rawValue
                ),
                pointerMotionCoalescing: displayConfiguration
                    .inputPipeline.pointerMotionCoalescing,
                touchMotionCoalescing: displayConfiguration.inputPipeline.touchMotionCoalescing
            )
        )
        try connection.completeInitialDiscovery(timeoutMilliseconds: discoveryTimeoutMilliseconds)
        let session = try DisplaySession(
            connection: connection,
            cursorConfiguration: cursorConfiguration,
            inputPipelineConfiguration: displayConfiguration.inputPipeline,
            keyboardInterpretationConfiguration: displayConfiguration.keyboardInterpretation
        )
        let displayCore = DisplayCore(session: session, eventHub: runtime.eventHub)
        session.setRawInvariantFailureReporter(displayCore)
        let source = DisplayEventSource(core: displayCore)
        lifecycle = .active(core: displayCore, eventSource: source)
        try runtime.installEventSource(source)
    }

    private func requireCore() throws -> DisplayCore {
        guard case .active(let core, _) = lifecycle else {
            throw ClientError.display(.closed)
        }

        return core
    }
}

private enum WaylandDisplayLifecycle {
    case initializing
    case active(core: DisplayCore, eventSource: DisplayEventSource)
    case closed
    case abandoned

    var isInitializing: Bool {
        switch self {
        case .initializing:
            true
        case .active, .closed, .abandoned:
            false
        }
    }
}

extension WaylandDisplay {
    public func clipboardOffer(for seatID: SeatID) throws -> ClipboardOffer? {
        try requireCore().clipboardOffer(for: seatID).map { offer in
            ClipboardOffer(snapshot: offer, display: self)
        }
    }

    /// Requests ownership of the regular clipboard selection for a seat.
    ///
    /// The compositor validates `serial` at the protocol boundary; this call creates and installs
    /// the local data source request but cannot prove compositor acceptance synchronously.
    public func requestClipboardSelection(
        _ configuration: ClipboardSourceConfiguration,
        seatID: SeatID,
        serial: InputSerial
    ) throws -> ClipboardSource {
        let source = try requireCore().setClipboard(
            configuration,
            seatID: seatID,
            serial: serial
        )
        return ClipboardSource(snapshot: source, display: self)
    }

    /// Requests clearing the regular clipboard selection for a seat.
    ///
    /// The compositor validates `serial` at the protocol boundary.
    public func requestClearClipboard(seatID: SeatID, serial: InputSerial) throws {
        try requireCore().clearClipboard(seatID: seatID, serial: serial)
    }

    package func requestClearClipboard(
        sourceID: DataSourceID,
        seatID: SeatID,
        serial: InputSerial
    ) throws {
        try requireCore().clearClipboard(
            sourceID: sourceID,
            seatID: seatID,
            serial: serial
        )
    }

    package func receiveClipboardOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        try requireCore().receiveClipboardOffer(id: offerID, mimeType: mimeType)
    }
}

@safe
private final class WaylandDisplayRuntime: Sendable {
    let executor: WaylandThreadExecutor
    let eventHub: DisplayEventHub

    init(configuration displayConfiguration: DisplayConfiguration) throws {
        eventHub = DisplayEventHub(
            configuration: displayConfiguration.eventStreams,
            diagnosticsConfiguration: displayConfiguration.diagnostics
        )
        executor = try WaylandThreadExecutor()
    }

    deinit {
        executor.shutdown()
    }

    var events: DisplayEvents {
        eventHub.displayEvents()
    }

    var inputEvents: InputEvents {
        eventHub.inputEvents()
    }

    var dataTransferEvents: DataTransferEvents {
        eventHub.dataTransferEvents()
    }

    var diagnostics: DisplayDiagnostics {
        eventHub.diagnostics()
    }

    func installEventSource(_ source: any WaylandThreadEventSource) throws {
        try executor.installEventSource(source)
    }

    func clearEventSource(_ source: (any WaylandThreadEventSource)?) {
        executor.clearEventSource(source)
    }

    func actorDidDeinitialize(lifecycle: inout WaylandDisplayLifecycle) {
        switch lifecycle {
        case .closed, .abandoned:
            executor.requestStopAfterCurrentJob()
            return
        case .initializing:
            eventHub.finish(throwing: .closed)
            lifecycle = .closed
            executor.requestStopAfterCurrentJob()
            return
        case .active(let leakedCore, _):
            #if DEBUG
                assertionFailure("WaylandDisplay leaked; call close() or use withConnection(_:)")
            #endif

            eventHub.finish(throwing: .closed)
            executor.abandonWaylandEventSourceWithoutDestroyingRawResources()

            // A missed close can deinitialize from an arbitrary thread. Normal
            // Wayland teardown is ordered owner-thread work, so release builds
            // abandon the raw graph instead of faking cleanup from deinit.
            unsafe intentionallyLeakObjectForWrongThreadResourceFallback(leakedCore)
            lifecycle = .abandoned
            executor.requestStopAfterCurrentJob(.abandonWaylandSources)
        }
    }
}

@safe
private final class DisplayEventSource: WaylandThreadEventSource {
    private let core: DisplayCore

    init(core displayCore: DisplayCore) {
        core = displayCore
    }

    var isClosed: Bool {
        core.isClosed
    }

    func fileDescriptor() throws -> CInt {
        try core.fileDescriptor()
    }

    func dispatchPending() throws -> Int32 {
        try core.dispatchPending()
    }

    func prepareRead() throws -> Bool {
        try core.prepareRead()
    }

    func flush() throws -> Bool {
        try core.flush()
    }

    func readEvents() throws {
        try core.readEvents()
    }

    func cancelRead() {
        core.cancelRead()
    }

    func handleEventLoopError(_ error: any Error) {
        core.fail(displayError(for: error))
    }

    private func displayError(for error: any Error) -> WaylandDisplayError {
        if let displayError = error as? WaylandDisplayError {
            return displayError
        }

        if let runtimeError = error as? RuntimeError {
            return WaylandDisplayError(runtimeError)
        }

        if let executorError = error as? WaylandThreadExecutorError {
            return WaylandDisplayError(executorError)
        }

        return .internalInvariantViolation(.message(String(describing: error)))
    }
}
