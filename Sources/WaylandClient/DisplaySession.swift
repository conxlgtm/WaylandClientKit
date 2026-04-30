import WaylandCursor
import WaylandKeyboardInterpretation
import WaylandRaw

package final class DisplaySession {
    package static let defaultDiscoveryTimeoutMilliseconds: Int32 = 1_000

    private let connection: RawDisplayConnection
    private let inputRouter = InputRouter()
    private let keyboardInterpreter: KeyboardInterpreter
    private let cursorManager: CursorManager
    private let maximumPendingInputEventCount: Int
    private var pendingInputEvents: [InputEvent] = []
    private var nextWindowID: UInt64 = 1

    package init(
        connection rawConnection: RawDisplayConnection,
        cursorConfiguration: CursorConfiguration = .init(),
        maximumPendingInputEventCount pendingInputCapacity: Int =
            EventStreamConfiguration().inputEventCapacity
    ) throws {
        rawConnection.preconditionIsOwnerThread()
        precondition(pendingInputCapacity > 0, "Pending input event capacity must be positive")
        connection = rawConnection
        keyboardInterpreter = try KeyboardInterpreter()
        cursorManager = try CursorManager(
            connection: rawConnection,
            configuration: cursorConfiguration
        )
        maximumPendingInputEventCount = pendingInputCapacity
    }

    @available(
        *,
        noasync,
        message: "Use a synchronous owner-thread Wayland loop."
    )
    package static func connect(
        cursorConfiguration: CursorConfiguration = .init(),
        discoveryTimeoutMilliseconds: Int32 = defaultDiscoveryTimeoutMilliseconds
    ) throws -> DisplaySession {
        let connection = try RawDisplayConnection.connect()
        try connection.completeInitialDiscovery(timeoutMilliseconds: discoveryTimeoutMilliseconds)
        return try DisplaySession(
            connection: connection,
            cursorConfiguration: cursorConfiguration
        )
    }

    @available(
        *,
        noasync,
        message: "Pump events from the owner-thread Wayland loop."
    )
    package func pumpEvents(timeoutMilliseconds: Int32 = -1) throws {
        try pumpEventsOnOwnerThread(timeoutMilliseconds: timeoutMilliseconds)
    }

    @available(
        *,
        noasync,
        message: "Read cursor state from the owner-thread Wayland loop."
    )
    package var pointerCursor: PointerCursor {
        pointerCursorOnOwnerThread
    }

    @discardableResult
    @available(
        *,
        noasync,
        message: "Mutate cursor state from the owner-thread Wayland loop."
    )
    package func setPointerCursor(_ cursor: PointerCursor) throws -> [CursorRequestResult] {
        try setPointerCursorOnOwnerThread(cursor)
    }

    @available(
        *,
        noasync,
        message: "Drain input from the owner-thread Wayland loop."
    )
    package func drainInputEvents() -> [InputEvent] {
        drainInputEventsOnOwnerThread()
    }

    @available(
        *,
        noasync,
        message: "Create windows from the owner-thread Wayland loop."
    )
    package func createTopLevelWindow(
        configuration windowConfiguration: WindowConfiguration = .init()
    ) throws -> TopLevelWindow {
        try createTopLevelWindowOnOwnerThread(configuration: windowConfiguration)
    }

    package func pumpEventsOnOwnerThread(timeoutMilliseconds: Int32 = -1) throws {
        connection.preconditionIsOwnerThread()
        try connection.pumpEvents(timeoutMilliseconds: timeoutMilliseconds)
        processPendingRawInputEvents()
    }

    package func pumpEventsOnOwnerThread(
        timeoutMilliseconds: Int32,
        wakeFileDescriptor: CInt,
        drainWakeFileDescriptor: @escaping () -> Void
    ) throws {
        connection.preconditionIsOwnerThread()
        try connection.pumpEvents(
            timeoutMilliseconds: timeoutMilliseconds,
            wakeFileDescriptor: wakeFileDescriptor,
            drainWakeFileDescriptor: drainWakeFileDescriptor
        )
        processPendingRawInputEvents()
    }

    package var eventLoopFileDescriptorOnOwnerThread: CInt {
        connection.preconditionIsOwnerThread()
        return connection.eventLoopFileDescriptor
    }

    @discardableResult
    package func dispatchPendingEventsOnOwnerThread() throws -> Int32 {
        connection.preconditionIsOwnerThread()
        let dispatchedCount = try connection.dispatchPendingEvents()
        processPendingRawInputEvents()
        return dispatchedCount
    }

    package func prepareReadEventsOnOwnerThread() throws -> Bool {
        connection.preconditionIsOwnerThread()
        return try connection.prepareReadEvents()
    }

    package func flushForExternalEventLoopOnOwnerThread() throws -> Bool {
        connection.preconditionIsOwnerThread()
        return try connection.flushForExternalEventLoop()
    }

    package func readEventsOnOwnerThread() throws {
        connection.preconditionIsOwnerThread()
        try connection.readEvents()
    }

    package func cancelReadEventsOnOwnerThread() {
        connection.preconditionIsOwnerThread()
        connection.cancelReadEvents()
    }

    package var pointerCursorOnOwnerThread: PointerCursor {
        connection.preconditionIsOwnerThread()
        return cursorManager.pointerCursor
    }

    @discardableResult
    package func setPointerCursorOnOwnerThread(
        _ cursor: PointerCursor
    ) throws -> [CursorRequestResult] {
        connection.preconditionIsOwnerThread()
        return try cursorManager.setPointerCursor(cursor)
    }

    package func drainInputEventsOnOwnerThread() -> [InputEvent] {
        connection.preconditionIsOwnerThread()
        processPendingRawInputEvents()

        defer { pendingInputEvents.removeAll(keepingCapacity: true) }
        return pendingInputEvents
    }

    package func createTopLevelWindowOnOwnerThread(
        configuration windowConfiguration: WindowConfiguration = .init()
    ) throws -> TopLevelWindow {
        connection.preconditionIsOwnerThread()
        let windowID = allocateWindowID()
        let window = try TopLevelWindow(
            id: windowID,
            connection: connection,
            configuration: windowConfiguration
        ) { [weak self] timeoutMilliseconds in
            guard let self else {
                throw ClientError.displayClosed
            }

            try pumpEventsOnOwnerThread(timeoutMilliseconds: timeoutMilliseconds)
        }
        let surfaceID = window.surfaceID

        inputRouter.register(windowID: windowID, surfaceID: surfaceID)
        cursorManager.register(surfaceID: surfaceID)
        window.onClose = { [cursorManager, inputRouter] in
            inputRouter.unregister(surfaceID: surfaceID)
            cursorManager.unregister(surfaceID: surfaceID)
        }

        return window
    }

    private func allocateWindowID() -> WindowID {
        connection.preconditionIsOwnerThread()
        defer { nextWindowID += 1 }
        return WindowID(rawValue: nextWindowID)
    }

    private func processPendingRawInputEvents() {
        let routedEvents = routeSessionInputEvents(
            from: connection.drainInputEvents(),
            inputRouter: inputRouter,
            keyboardInterpreter: keyboardInterpreter,
            rawInputObserver: cursorManager
        )

        appendPendingInputEvents(routedEvents)
    }

    private func appendPendingInputEvents(_ inputEvents: [InputEvent]) {
        guard !inputEvents.isEmpty else { return }

        guard pendingInputEvents.count + inputEvents.count <= maximumPendingInputEventCount else {
            pendingInputEvents.removeAll(keepingCapacity: true)
            let firstEvent = inputEvents[0]
            let message = "session input queue exceeded capacity \(maximumPendingInputEventCount)"
            pendingInputEvents.append(
                InputEvent(
                    sequence: firstEvent.sequence,
                    seatID: firstEvent.seatID,
                    windowID: nil,
                    kind: .diagnostic(
                        InputDiagnostic(
                            operation: .queueOverflow,
                            message: message
                        )
                    )
                )
            )
            return
        }

        pendingInputEvents.append(contentsOf: inputEvents)
    }
}

func routeSessionInputEvents(
    from rawEvents: [RawInputEvent],
    inputRouter: InputRouter,
    keyboardInterpreter: KeyboardInterpreter,
    rawInputObserver: RawInputEventObserving? = nil
) -> [InputEvent] {
    var inputEvents: [InputEvent] = []
    for rawEvent in rawEvents {
        inputEvents.append(contentsOf: rawInputObserver?.observe(rawEvent) ?? [])
        inputEvents.append(contentsOf: inputRouter.route(rawEvent))

        for interpretedEvent in keyboardInterpreter.consume(rawEvent) {
            inputEvents.append(contentsOf: inputRouter.route(interpretedEvent))
        }
    }

    return inputEvents
}
