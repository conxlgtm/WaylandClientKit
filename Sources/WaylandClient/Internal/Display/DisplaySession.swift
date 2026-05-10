import Foundation
import WaylandCursor
import WaylandKeyboard
import WaylandRaw

package final class DisplaySession {  // swiftlint:disable:this type_body_length
    package static let defaultDiscoveryTimeoutMilliseconds: Int32 = 1_000

    package let connection: RawDisplayConnection
    private let inputRouter = InputRouter()
    private let keyboardInterpreter: KeyboardInterpreter
    private let cursorManager: CursorManager
    package let dataTransferGlobalProvider: any DataTransferGlobalProviding
    package let dataTransferManager: DataTransferManager
    package let primarySelectionController: PrimarySelectionController
    package let dataTransferSourceWriter: ThreadedDataTransferSourceWriter
    private let dataTransferEventQueue = DataTransferEventQueue()
    private let maximumPendingInputEventCount: Int
    private var pendingInputState = PendingInputState.accepting([])
    package var pendingDataTransferDiagnostics: [DataTransferDiagnostic] = []
    private var nextWindowID: UInt64 = 1
    private var nextPopupID: UInt64 = 1

    package init(
        connection rawConnection: RawDisplayConnection,
        cursorConfiguration: CursorConfiguration = .init(),
        inputPipelineConfiguration: InputPipelineConfiguration = .init(),
        keyboardInterpretationConfiguration: KeyboardInterpretationConfiguration = .init(),
        dataTransferSourceWriter sourceWriter: ThreadedDataTransferSourceWriter =
            ThreadedDataTransferSourceWriter()
    ) throws {
        rawConnection.preconditionIsOwnerThread()
        connection = rawConnection
        keyboardInterpreter = try KeyboardInterpreter(
            configuration: Self.keyboardInterpreterConfiguration(
                for: keyboardInterpretationConfiguration
            ),
            composeEnvironment: Self.keyboardComposeEnvironment()
        )
        cursorManager = try CursorManager(
            connection: rawConnection, configuration: cursorConfiguration)
        dataTransferGlobalProvider = rawConnection
        dataTransferManager = DataTransferManager(
            connection: rawConnection,
            eventQueue: dataTransferEventQueue
        )
        primarySelectionController = PrimarySelectionController(
            connection: rawConnection,
            eventQueue: dataTransferEventQueue
        )
        dataTransferSourceWriter = sourceWriter
        maximumPendingInputEventCount =
            inputPipelineConfiguration.pendingInputEventCapacity.rawValue
    }

    package static func keyboardInterpreterConfiguration(
        for configuration: KeyboardInterpretationConfiguration
    ) -> WaylandKeyboard.KeyboardInterpreterConfiguration {
        .init(configuration)
    }

    package static func keyboardComposeEnvironment() -> WaylandKeyboard.KeyboardComposeEnvironment {
        .init(ProcessInfo.processInfo.environment)
    }

    func releaseWaylandResourcesOnOwnerThread() {
        connection.preconditionIsOwnerThread()
        primarySelectionController.shutdown()
        dataTransferManager.shutdown()
        dataTransferSourceWriter.shutdown()
    }

    deinit {
        releaseWaylandResourcesOnOwnerThread()
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
        configuration windowConfiguration: WindowConfiguration = .default,
        failureSink: any WindowFailureSink = DefaultWindowFailureSink()
    ) throws -> TopLevelWindow {
        try createTopLevelWindowOnOwnerThread(
            configuration: windowConfiguration,
            failureSink: failureSink
        )
    }

    package func pumpEventsOnOwnerThread(timeoutMilliseconds: Int32 = -1) throws {
        connection.preconditionIsOwnerThread()
        try connection.pumpEvents(timeoutMilliseconds: timeoutMilliseconds)
        try processPendingRawInputEvents()
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
        try processPendingRawInputEvents()
    }

    package var eventLoopFileDescriptorOnOwnerThread: CInt {
        connection.preconditionIsOwnerThread()
        return connection.eventLoopFileDescriptor
    }

    @discardableResult
    package func dispatchPendingEventsOnOwnerThread() throws -> Int32 {
        connection.preconditionIsOwnerThread()
        let dispatchedCount = try connection.dispatchPendingEvents()
        try processPendingRawInputEvents()
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

    package func outputSnapshotsOnOwnerThread() throws -> [OutputSnapshot] {
        connection.preconditionIsOwnerThread()
        return try connection.outputSnapshots().map(OutputSnapshot.init)
    }

    package func drainOutputEventsOnOwnerThread() -> [DisplayEvent] {
        connection.preconditionIsOwnerThread()
        return connection.drainOutputEvents().map(DisplayEvent.init)
    }

    package func capabilitiesOnOwnerThread() -> WaylandCapabilities {
        connection.preconditionIsOwnerThread()
        return WaylandCapabilities.fromAdvertisedProtocols(
            [
                advertisedProtocol(named: "wl_data_device_manager"),
                advertisedProtocol(named: "zwp_primary_selection_device_manager_v1"),
                advertisedProtocol(named: "zxdg_decoration_manager_v1"),
                advertisedProtocol(named: "zxdg_output_manager_v1"),
                advertisedProtocol(named: "wp_viewporter"),
                advertisedProtocol(named: "wp_fractional_scale_manager_v1"),
            ].compactMap(\.self))
    }

    private func advertisedProtocol(named interfaceName: String) -> AdvertisedWaylandProtocol? {
        guard let global = connection.optionalGlobal(named: interfaceName) else {
            return nil
        }

        return AdvertisedWaylandProtocol(
            interfaceName: global.interfaceName,
            advertisedVersion: global.advertisedVersion.value
        )
    }

    package func setRawInvariantFailureReporter(
        _ reporter: (any RawInvariantFailureReporter)?
    ) {
        connection.preconditionIsOwnerThread()
        connection.setInvariantFailureReporter(reporter)
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
        processPendingSessionInputEvents()

        return pendingInputState.drain()
    }

    package func drainDataTransferEventsOnOwnerThread() -> [DataTransferEvent] {
        connection.preconditionIsOwnerThread()
        let events = dataTransferEventQueue.drain()
        cancelSourceWrites(for: events)
        return events
    }

    package func createTopLevelWindowOnOwnerThread(
        configuration windowConfiguration: WindowConfiguration = .default,
        failureSink: any WindowFailureSink = DefaultWindowFailureSink()
    ) throws -> TopLevelWindow {
        connection.preconditionIsOwnerThread()
        let windowID = allocateWindowID()
        let window = try TopLevelWindow(
            id: windowID,
            connection: connection,
            configuration: windowConfiguration,
            failureSink: failureSink
        ) { [weak self] timeoutMilliseconds in
            guard let self else {
                throw ClientError.display(.closed)
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

    private func allocatePopupID() -> PopupID {
        connection.preconditionIsOwnerThread()
        defer { nextPopupID += 1 }
        return PopupID(rawValue: nextPopupID)
    }

    private func processPendingRawInputEvents() throws {
        try processInputDataTransferState()
        processPendingSessionInputEvents()
    }

    private func processPendingSessionInputEvents() {
        if pendingInputState.hasFailed {
            _ = connection.drainInputEvents()
            return
        }

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
        pendingInputState.append(
            inputEvents,
            capacity: maximumPendingInputEventCount,
            makeOverflowEvent: makePendingInputOverflowDiagnostic
        )
    }

    private func makePendingInputOverflowDiagnostic(from event: InputEvent) -> InputEvent {
        InputEvent(
            sequence: event.sequence,
            seatID: event.seatID,
            target: .display,
            kind: .diagnostic(
                InputDiagnostic(
                    .inputPipelineOverflow(
                        InputPipelineOverflow(
                            stage: .sessionPendingInput,
                            capacity: InputPipelineCapacity(
                                unchecked: maximumPendingInputEventCount
                            )
                        )
                    )
                )
            )
        )
    }
}

enum PendingInputState {
    case accepting([InputEvent])
    case failed(bufferedPrefix: [InputEvent], overflow: PendingInputOverflowEvent)
    case drainedAfterFailure

    var hasFailed: Bool {
        switch self {
        case .accepting:
            false
        case .failed, .drainedAfterFailure:
            true
        }
    }

    mutating func append(
        _ inputEvents: [InputEvent],
        capacity: Int,
        makeOverflowEvent: (InputEvent) -> InputEvent
    ) {
        guard case .accepting(var pendingEvents) = self else { return }

        for inputEvent in inputEvents {
            if let overflow = PendingInputOverflowEvent(inputEvent) {
                self = .failed(bufferedPrefix: pendingEvents, overflow: overflow)
                return
            }

            guard pendingEvents.count < capacity else {
                self = .failed(
                    bufferedPrefix: pendingEvents,
                    overflow: PendingInputOverflowEvent(
                        from: inputEvent,
                        makeOverflowEvent: makeOverflowEvent
                    )
                )
                return
            }

            pendingEvents.append(inputEvent)
        }

        self = .accepting(pendingEvents)
    }

    mutating func drain() -> [InputEvent] {
        switch self {
        case .accepting(let inputEvents):
            self = .accepting([])
            return inputEvents
        case .failed(let bufferedPrefix, let overflow):
            self = .drainedAfterFailure
            return bufferedPrefix + [overflow.inputEvent]
        case .drainedAfterFailure:
            return []
        }
    }
}

struct PendingInputOverflowEvent {
    let inputEvent: InputEvent

    init?(_ event: InputEvent) {
        guard Self.isInputPipelineOverflowDiagnostic(event) else { return nil }
        inputEvent = event
    }

    init(
        from rejectedEvent: InputEvent,
        makeOverflowEvent: (InputEvent) -> InputEvent
    ) {
        let overflow = makeOverflowEvent(rejectedEvent)
        precondition(
            Self.isInputPipelineOverflowDiagnostic(overflow),
            "Pending input overflow event must be an input-pipeline overflow diagnostic"
        )
        inputEvent = overflow
    }

    private static func isInputPipelineOverflowDiagnostic(_ event: InputEvent) -> Bool {
        guard case .diagnostic(let diagnostic) = event.kind else { return false }
        if case .inputPipelineOverflow = diagnostic.operation {
            return true
        }

        return false
    }
}

extension DisplaySession {
    package func createPopupOnOwnerThread(
        parent parentWindow: TopLevelWindow,
        configuration popupConfiguration: PopupConfiguration,
        failureSink: any WindowFailureSink = DefaultWindowFailureSink()
    ) throws -> PopupRoleSurface {
        connection.preconditionIsOwnerThread()
        let popup = try parentWindow.createPopupOnOwnerThread(
            id: allocatePopupID(),
            configuration: popupConfiguration,
            failureSink: failureSink
        )
        let popupSurfaceID = popup.surfaceID

        try inputRouter.registerPopup(
            popupID: popup.id,
            parentSurfaceID: parentWindow.surfaceID,
            surfaceID: popupSurfaceID
        )
        cursorManager.register(surfaceID: popupSurfaceID)
        popup.onClose = { [cursorManager, inputRouter] in
            inputRouter.unregister(surfaceID: popupSurfaceID)
            cursorManager.unregister(surfaceID: popupSurfaceID)
        }

        return popup
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
        if let acceptedEvent = inputRouter.acceptRawInputEvent(rawEvent) {
            inputEvents.append(contentsOf: rawInputObserver?.observe(acceptedEvent.raw) ?? [])
            inputEvents.append(contentsOf: inputRouter.route(acceptedEvent))

            for interpretedEvent in keyboardInterpreter.consume(acceptedEvent.raw) {
                inputEvents.append(contentsOf: inputRouter.route(interpretedEvent))
            }
        }
    }

    return inputEvents
}
