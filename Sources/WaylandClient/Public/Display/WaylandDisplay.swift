import Foundation
import WaylandRaw
import WaylandRuntime

public actor WaylandDisplay {
    public static let defaultDiscoveryTimeoutMilliseconds: Int32 = 1_000
    public static let defaultConfigureTimeoutMilliseconds: Int32 = 1_000

    nonisolated let runtime: WaylandDisplayRuntime
    private var lifecycle = WaylandDisplayLifecycle.initializing
    private var cursorAnimationTask: Task<Void, Never>?, cursorAnimationTaskGeneration: UInt64 = 0

    private typealias WindowCloseObserver = @Sendable () async -> Void

    private var windowCloseObservers: [WindowID: [UUID: WindowCloseObserver]] = [:]

    nonisolated public var unownedExecutor: UnownedSerialExecutor {
        unsafe runtime.executor.asUnownedSerialExecutor()
    }

    nonisolated public var events: DisplayEvents {
        runtime.events
    }

    nonisolated public var inputEvents: InputEvents {
        runtime.inputEvents
    }

    nonisolated public var dataTransferEvents: DataTransferEvents {
        runtime.dataTransferEvents
    }

    nonisolated public var diagnostics: DisplayDiagnostics {
        runtime.diagnostics
    }

    private init(runtime displayRuntime: WaylandDisplayRuntime) {
        runtime = displayRuntime
    }

    isolated deinit {
        cursorAnimationTask?.cancel()
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

    public func currentPointerCursor() throws -> PointerCursor {
        try requireCore().currentPointerCursor()
    }

    /// Returns compositor protocol features discovered during connection setup.
    ///
    /// This is a side-effect-free registry query. Request APIs still validate availability at
    /// use time because Wayland globals may disappear after initial discovery.
    public func capabilities() throws -> WaylandCapabilities {
        try requireCore().capabilities()
    }

    @discardableResult
    public func setPointerCursor(_ cursor: PointerCursor) throws -> [CursorRequestResult] {
        let results = try requireCore().setPointerCursor(cursor)
        updateCursorAnimationTask(for: cursor)
        return results
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

    package func requestPresentationFeedback(_ windowID: WindowID) throws {
        try requireCore().requestPresentationFeedback(windowID)
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

    package func closeWindow(_ windowID: WindowID) async {
        await notifyWindowCloseObservers(for: windowID)

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

    package func closeSubsurface(_ subsurfaceID: SubsurfaceID) {
        guard case .active(let core, _) = lifecycle else {
            return
        }

        core.closeSubsurface(subsurfaceID)
    }

    public func close() async {
        cursorAnimationTaskGeneration += 1
        cursorAnimationTask?.cancel()
        cursorAnimationTask = nil
        switch lifecycle {
        case .active(let activeCore, let activeEventSource):
            await notifyAllWindowCloseObservers()
            runtime.clearEventSource(activeEventSource)
            activeCore.close()
            lifecycle = .closed
        case .primarySelectionTestHarness:
            runtime.eventHub.finish()
            lifecycle = .closed
        case .initializing, .closed, .abandoned:
            lifecycle = .closed
        }
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
        updateCursorAnimationTask(for: cursorConfiguration.fallbackCursor)
    }

    func requireCore() throws -> DisplayCore {
        guard case .active(let core, _) = lifecycle else {
            throw ClientError.display(.closed)
        }

        return core
    }
}

extension WaylandDisplay {
    public func outputs() throws -> [OutputSnapshot] {
        try requireCore().outputs()
    }

    public func outputTopology() throws -> [OutputSnapshot] {
        try outputs().sorted { lhs, rhs in
            lhs.id.rawValue < rhs.id.rawValue
        }
    }
}

extension WaylandDisplay {
    @discardableResult
    package func registerWindowCloseObserver(
        for windowID: WindowID,
        _ observer: @escaping @Sendable () async -> Void
    ) -> UUID {
        let observerID = UUID()
        windowCloseObservers[windowID, default: [:]][observerID] = observer
        return observerID
    }

    private func notifyWindowCloseObservers(for windowID: WindowID) async {
        let observers: [WindowCloseObserver]
        if let observersByID = windowCloseObservers.removeValue(forKey: windowID) {
            observers = Array(observersByID.values)
        } else {
            observers = []
        }
        for observer in observers {
            await observer()
        }
    }

    private func notifyAllWindowCloseObservers() async {
        var observerGroups: [[WindowCloseObserver]] = []
        for observersByID in windowCloseObservers.values {
            observerGroups.append(Array(observersByID.values))
        }
        windowCloseObservers.removeAll()
        for observers in observerGroups {
            for observer in observers {
                await observer()
            }
        }
    }
}

extension WaylandDisplay {
    public var isClosed: Bool {
        switch lifecycle {
        case .active(let core, _):
            return core.isClosed
        case .primarySelectionTestHarness:
            return false
        case .initializing, .closed, .abandoned:
            return true
        }
    }

    static func primarySelectionTestHarness<
        Handler: Sendable & WaylandDisplayPrimarySelectionHandling
    >(
        primarySelectionHandler makeHandler:
            @Sendable (DisplayEventHub) throws -> Handler
    ) async throws -> (display: WaylandDisplay, handler: Handler) {
        let runtime = try WaylandDisplayRuntime(configuration: DisplayConfiguration())
        let handler = try makeHandler(runtime.eventHub)
        let display = WaylandDisplay(runtime: runtime)
        await display.installPrimarySelectionTestHarness(handler)
        return (display, handler)
    }

    private func installPrimarySelectionTestHarness<
        Handler: Sendable & WaylandDisplayPrimarySelectionHandling
    >(
        _ handler: Handler
    ) {
        precondition(
            lifecycle.isInitializing,
            "WaylandDisplay primary-selection test harness installed more than once"
        )
        lifecycle = .primarySelectionTestHarness(handler)
    }

    func requirePrimarySelectionHandler() throws -> any WaylandDisplayPrimarySelectionHandling {
        switch lifecycle {
        case .active(let core, _):
            return core
        case .primarySelectionTestHarness(let handler):
            return handler
        case .initializing, .closed, .abandoned:
            throw ClientError.display(.closed)
        }
    }
}

extension WaylandDisplay {
    private func updateCursorAnimationTask(for cursor: PointerCursor) {
        cursorAnimationTaskGeneration += 1
        guard cursor.animation != nil else {
            cursorAnimationTask?.cancel()
            cursorAnimationTask = nil
            return
        }

        cursorAnimationTask?.cancel()
        let generation = cursorAnimationTaskGeneration

        cursorAnimationTask = Task { [weak self] in  // swiftlint:disable:this no_unstructured_task
            await self?.runCursorAnimationLoop(generation: generation)
        }
    }

    private func runCursorAnimationLoop(generation: UInt64) async {
        defer {
            if cursorAnimationTaskGeneration == generation {
                cursorAnimationTask = nil
            }
        }

        while !Task.isCancelled, cursorAnimationTaskGeneration == generation {
            let delay: Duration?
            do {
                delay = try requireCore().nextCursorAnimationDelay()
            } catch {
                return
            }

            guard let delay else { return }

            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard cursorAnimationTaskGeneration == generation else { return }

            do {
                _ = try requireCore().advanceCursorAnimations()
            } catch {
                return
            }
        }
    }
}
