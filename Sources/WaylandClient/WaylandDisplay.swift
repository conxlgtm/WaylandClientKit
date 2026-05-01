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
        let invariantFailureSink = RawInvariantFailureSink()
        let connection = try RawDisplayConnection.connect(
            invariantFailureSink: invariantFailureSink
        )
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

        // A missed close can deinitialize from an arbitrary thread. Normal
        // Wayland teardown is ordered owner-thread work, so release builds
        // abandon the raw graph instead of faking cleanup from deinit.
        if let leakedCore = core {
            unsafe intentionallyLeakObjectForWrongThreadResourceFallback(leakedCore)
            core = nil
        }

        executor.requestStopAfterCurrentJob(abandoningWaylandSources: true)
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
