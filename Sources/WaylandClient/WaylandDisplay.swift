import WaylandRaw
import WaylandRawUnsafeShim

public actor WaylandDisplay {
    public static let defaultDiscoveryTimeoutMilliseconds: Int32 = 1_000
    public static let defaultConfigureTimeoutMilliseconds: Int32 = 1_000

    private nonisolated let runtime: WaylandDisplayRuntime
    private var core: DisplayCore?
    private var eventSource: DisplayEventSource?
    private var didCloseBeforeDeinit = false

    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        unsafe runtime.executor.asUnownedSerialExecutor()
    }

    public nonisolated var events: DisplayEvents {
        runtime.events
    }

    public nonisolated var inputEvents: InputEvents {
        runtime.inputEvents
    }

    private init(runtime displayRuntime: WaylandDisplayRuntime) {
        runtime = displayRuntime
    }

    isolated deinit {
        runtime.actorDidDeinitialize(core: &core, didClose: didCloseBeforeDeinit)
    }

    public static func connect(
        cursorConfiguration: CursorConfiguration = .init(),
        discoveryTimeoutMilliseconds: Int32 = defaultDiscoveryTimeoutMilliseconds,
        eventStreamConfiguration: EventStreamConfiguration = .init()
    ) async throws -> WaylandDisplay {
        let runtime = try WaylandDisplayRuntime(eventStreamConfiguration: eventStreamConfiguration)
        let display = WaylandDisplay(runtime: runtime)
        try await display.initialize(
            cursorConfiguration: cursorConfiguration,
            discoveryTimeoutMilliseconds: discoveryTimeoutMilliseconds,
            eventStreamConfiguration: eventStreamConfiguration
        )
        return display
    }

    public static func withConnection<ResultValue: Sendable>(
        cursorConfiguration: CursorConfiguration = .init(),
        discoveryTimeoutMilliseconds: Int32 = defaultDiscoveryTimeoutMilliseconds,
        eventStreamConfiguration: EventStreamConfiguration = .init(),
        _ body: @Sendable (WaylandDisplay) async throws -> ResultValue
    ) async throws -> ResultValue {
        let display = try await connect(
            cursorConfiguration: cursorConfiguration,
            discoveryTimeoutMilliseconds: discoveryTimeoutMilliseconds,
            eventStreamConfiguration: eventStreamConfiguration
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

    public var isClosed: Bool {
        core?.isClosed ?? true
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
        configuration windowConfiguration: WindowConfiguration = .init()
    ) throws -> Window {
        let windowID = try createTopLevelWindowID(configuration: windowConfiguration)
        return Window(id: windowID, display: self)
    }

    @discardableResult
    public func createTopLevelWindowID(
        configuration windowConfiguration: WindowConfiguration = .init()
    ) throws -> WindowID {
        try requireCore().createTopLevelWindowID(configuration: windowConfiguration)
    }

    public func showWindow(
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

    public func redraw(
        _ windowID: WindowID,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try requireCore().redraw(windowID, draw)
    }

    public func windowIsClosed(_ windowID: WindowID) throws -> Bool {
        try requireCore().windowIsClosed(windowID)
    }

    public func windowNeedsRedraw(_ windowID: WindowID) throws -> Bool {
        try requireCore().windowNeedsRedraw(windowID)
    }

    public func requestRedraw(_ windowID: WindowID) throws {
        try requireCore().requestRedraw(windowID)
    }

    public func closeWindow(_ windowID: WindowID) {
        core?.closeWindow(windowID)
    }

    public func close() {
        guard let activeCore = core else {
            didCloseBeforeDeinit = true
            return
        }

        runtime.clearEventSource(eventSource)
        activeCore.close()
        eventSource = nil
        core = nil
        didCloseBeforeDeinit = true
    }

    private func initialize(
        cursorConfiguration: CursorConfiguration,
        discoveryTimeoutMilliseconds: Int32,
        eventStreamConfiguration: EventStreamConfiguration
    ) throws {
        precondition(core == nil, "WaylandDisplay initialized more than once")
        let connection = try RawDisplayConnection.connect()
        try connection.completeInitialDiscovery(timeoutMilliseconds: discoveryTimeoutMilliseconds)
        let session = try DisplaySession(
            connection: connection,
            cursorConfiguration: cursorConfiguration,
            maximumPendingInputEventCount: eventStreamConfiguration.inputEventCapacity
        )
        let displayCore = DisplayCore(session: session, eventHub: runtime.eventHub)
        session.setRawInvariantFailureReporter(displayCore)
        let source = DisplayEventSource(core: displayCore)
        core = displayCore
        eventSource = source
        try runtime.installEventSource(source)
    }

    private func requireCore() throws -> DisplayCore {
        guard let core else {
            throw ClientError.displayClosed
        }

        return core
    }
}

@safe
private final class WaylandDisplayRuntime: Sendable {
    let executor: WaylandThreadExecutor
    let eventHub: DisplayEventHub

    init(eventStreamConfiguration: EventStreamConfiguration) throws {
        try eventStreamConfiguration.validate()
        eventHub = DisplayEventHub(configuration: eventStreamConfiguration)
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

    func installEventSource(_ source: any WaylandThreadEventSource) throws {
        try executor.installEventSource(source)
    }

    func clearEventSource(_ source: (any WaylandThreadEventSource)?) {
        executor.clearEventSource(source)
    }

    func actorDidDeinitialize(core: inout DisplayCore?, didClose: Bool) {
        #if DEBUG
            assert(didClose, "WaylandDisplay leaked; call close() or use withConnection(_:)")
        #endif

        guard !didClose else {
            executor.requestStopAfterCurrentJob(abandoningWaylandSources: false)
            return
        }

        eventHub.finish(throwing: .closed)
        executor.abandonWaylandEventSourceWithoutDestroyingRawResources()

        if let leakedCore = core {
            unsafe intentionallyLeakObjectForWrongThreadResourceFallback(leakedCore)
            core = nil
        }

        executor.requestStopAfterCurrentJob(abandoningWaylandSources: true)
    }
}

@safe
private final class DisplayCore: RawInvariantFailureReporter {
    private let eventHub: DisplayEventHub
    private var session: DisplaySession?
    private var windows: [WindowID: TopLevelWindow] = [:]
    private(set) var isClosed = false

    init(session activeSession: DisplaySession, eventHub displayEventHub: DisplayEventHub) {
        session = activeSession
        eventHub = displayEventHub
    }

    func currentPointerCursor() throws -> PointerCursor {
        try requireSession().pointerCursorOnOwnerThread
    }

    @discardableResult
    func setPointerCursor(_ cursor: PointerCursor) throws -> [CursorRequestResult] {
        try requireSession().setPointerCursorOnOwnerThread(cursor)
    }

    func createTopLevelWindowID(
        configuration windowConfiguration: WindowConfiguration = .init()
    ) throws -> WindowID {
        let window = try requireSession().createTopLevelWindowOnOwnerThread(
            configuration: windowConfiguration
        )
        installEventCallbacks(for: window)
        windows[window.id] = window
        return window.id
    }

    func showWindow(
        _ windowID: WindowID,
        timeoutMilliseconds: Int32,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        let window = try requireWindow(windowID)
        try window.showOnOwnerThread(timeoutMilliseconds: timeoutMilliseconds, draw)
        if let session {
            publishInputEvents(session.drainInputEventsOnOwnerThread())
        }
    }

    func redraw(
        _ windowID: WindowID,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        let window = try requireWindow(windowID)
        try window.redrawOnOwnerThread(draw)
    }

    func windowIsClosed(_ windowID: WindowID) throws -> Bool {
        try requireWindow(windowID).isClosedOnOwnerThread
    }

    func windowNeedsRedraw(_ windowID: WindowID) throws -> Bool {
        try requireWindow(windowID).needsRedrawOnOwnerThread
    }

    func requestRedraw(_ windowID: WindowID) throws {
        try requireWindow(windowID).requestRedrawOnOwnerThread()
    }

    func closeWindow(_ windowID: WindowID) {
        guard let window = windows.removeValue(forKey: windowID) else {
            return
        }

        window.closeOnOwnerThread()
        eventHub.publish(.windowClosed(windowID))
    }

    func close() {
        guard !isClosed else { return }

        isClosed = true
        for windowID in Array(windows.keys) {
            closeWindow(windowID)
        }

        session = nil
        eventHub.finish()
    }

    func fail(_ error: WaylandDisplayError) {
        guard !isClosed else { return }

        isClosed = true
        windows.removeAll(keepingCapacity: false)
        session = nil
        eventHub.finish(throwing: error)
    }

    func reportFatalRawInvariantFailure(_ failure: RawInvariantFailure) {
        fail(.internalInvariantViolation(failure.description))
    }

    func pumpOnce(
        timeoutMilliseconds: Int32,
        wakeFileDescriptor: CInt,
        drainWakeFileDescriptor: @escaping () -> Void
    ) throws {
        guard !isClosed else { return }
        let activeSession = try requireSession()
        try activeSession.pumpEventsOnOwnerThread(
            timeoutMilliseconds: timeoutMilliseconds,
            wakeFileDescriptor: wakeFileDescriptor,
            drainWakeFileDescriptor: drainWakeFileDescriptor
        )
        publishInputEvents(activeSession.drainInputEventsOnOwnerThread())
    }

    func fileDescriptor() throws -> CInt {
        try requireSession().eventLoopFileDescriptorOnOwnerThread
    }

    @discardableResult
    func dispatchPending() throws -> Int32 {
        guard !isClosed else { return 0 }
        let activeSession = try requireSession()
        let dispatchedCount = try activeSession.dispatchPendingEventsOnOwnerThread()
        publishInputEvents(activeSession.drainInputEventsOnOwnerThread())
        return dispatchedCount
    }

    func prepareRead() throws -> Bool {
        guard !isClosed else { return false }
        return try requireSession().prepareReadEventsOnOwnerThread()
    }

    func flush() throws -> Bool {
        guard !isClosed else { return false }
        return try requireSession().flushForExternalEventLoopOnOwnerThread()
    }

    func readEvents() throws {
        guard !isClosed else { return }
        try requireSession().readEventsOnOwnerThread()
    }

    func cancelRead() {
        guard !isClosed, let session else { return }
        session.cancelReadEventsOnOwnerThread()
    }

    private func publishInputEvents(_ inputEvents: [InputEvent]) {
        for inputEvent in inputEvents {
            eventHub.publishInput(inputEvent)
        }
    }

    private func installEventCallbacks(for window: TopLevelWindow) {
        let windowID = window.id

        window.onCloseRequested = { [weak core = self] in
            core?.handleWindowCloseRequested(windowID)
        }
        window.onRedrawRequested = { [weak core = self] in
            core?.eventHub.publish(.redrawRequested(windowID))
        }
    }

    private func handleWindowCloseRequested(_ windowID: WindowID) {
        eventHub.publish(.windowCloseRequested(windowID))

        guard let window = windows[windowID],
            window.closeRequestPolicy == .autoClose
        else {
            return
        }

        closeWindow(windowID)
    }

    private func requireSession() throws -> DisplaySession {
        guard let session, !isClosed else {
            throw ClientError.displayClosed
        }

        return session
    }

    private func requireWindow(_ windowID: WindowID) throws -> TopLevelWindow {
        guard let window = windows[windowID] else {
            throw ClientError.unknownWindow(windowID)
        }

        return window
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
        core.fail(WaylandDisplayError(error))
    }
}
