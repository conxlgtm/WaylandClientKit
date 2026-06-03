import Foundation
import WaylandKeyboard
import WaylandRaw

package final class DisplaySession {  // swiftlint:disable:this type_body_length
    package static let defaultDiscoveryTimeoutMilliseconds: Int32 = 1_000

    package let connection: RawDisplayConnection
    private let inputCoordinator: SessionInputCoordinator
    package let dataTransferGlobalProvider: any DataTransferGlobalProviding
    package let activationManager: ActivationManager
    package let pointerCaptureManager: PointerCaptureManager
    package let dataTransferManager: DataTransferManager
    package let primarySelectionController: PrimarySelectionController
    package let textInputManager: TextInputManager
    package let dataTransferSourceWriter: ThreadedDataTransferSourceWriter
    private let dataTransferEventQueue = DataTransferEventQueue()
    package var pendingDataTransferDiagnostics: [DataTransferDiagnostic] = []
    private var windowIDs = IDGenerator<WindowID>()
    private var popupIDs = IDGenerator<PopupID>()
    var subsurfaceIDs = IDGenerator<SubsurfaceID>()

    package init(
        connection rawConnection: RawDisplayConnection,
        cursorConfiguration: CursorConfiguration = .init(),
        inputPipelineConfiguration: InputPipelineConfiguration = .init(),
        keyboardInterpretationConfiguration: KeyboardInterpretationConfiguration = .init(),
        dataTransferSourceWriter sourceWriter: ThreadedDataTransferSourceWriter =
            ThreadedDataTransferSourceWriter()
    ) throws {
        rawConnection.preconditionIsOwnerThread()
        let inputRouter = InputRouter()
        let keyboardInterpreter = try KeyboardInterpreter(
            configuration: Self.keyboardInterpreterConfiguration(
                for: keyboardInterpretationConfiguration
            ),
            composeEnvironment: Self.keyboardComposeEnvironment()
        )
        let cursorManager = try CursorManager(
            connection: rawConnection, configuration: cursorConfiguration)
        let inputCoordinator = SessionInputCoordinator(
            inputRouter: inputRouter,
            keyboardInterpreter: keyboardInterpreter,
            cursorManager: cursorManager,
            maximumPendingInputEventCount:
                inputPipelineConfiguration.pendingInputEventCapacity.rawValue
        )

        connection = rawConnection
        self.inputCoordinator = inputCoordinator
        dataTransferGlobalProvider = rawConnection
        activationManager = ActivationManager(connection: rawConnection)
        pointerCaptureManager = PointerCaptureManager(connection: rawConnection)
        dataTransferManager = DataTransferManager(
            connection: rawConnection,
            eventQueue: dataTransferEventQueue
        ) { inputCoordinator.target(for: $0) }
        primarySelectionController = PrimarySelectionController(
            connection: rawConnection,
            eventQueue: dataTransferEventQueue
        )
        textInputManager = TextInputManager(connection: rawConnection) { target in
            inputCoordinator.target(for: target)
        }
        dataTransferSourceWriter = sourceWriter
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
        inputCoordinator.shutdown()
        primarySelectionController.shutdown()
        dataTransferManager.shutdown()
        textInputManager.shutdown()
        activationManager.shutdown()
        pointerCaptureManager.shutdown()
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
        return inputCoordinator.pointerCursor
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
        return Self.capabilities { interfaceName in
            advertisedProtocol(named: interfaceName)
        }
    }

    static func capabilities(
        advertisedProtocol namedProtocol: (String) -> AdvertisedWaylandProtocol?
    ) -> WaylandCapabilities {
        WaylandCapabilities.fromAdvertisedProtocols(
            capabilityProtocolInterfaceNames.compactMap(namedProtocol)
        )
    }

    static let capabilityProtocolInterfaceNames = [
        "wl_data_device_manager",
        "zwp_primary_selection_device_manager_v1",
        "zxdg_decoration_manager_v1",
        "zxdg_output_manager_v1",
        "wp_viewporter",
        "wp_presentation",
        "wp_fractional_scale_manager_v1",
        "wp_cursor_shape_manager_v1",
        "xdg_activation_v1",
        "xdg_toplevel_icon_manager_v1",
        "zwp_idle_inhibit_manager_v1",
        "xdg_system_bell_v1",
        "zwp_relative_pointer_manager_v1",
        "zwp_pointer_constraints_v1",
        "zwp_text_input_manager_v3",
        "zwp_linux_dmabuf_v1",
    ]

    package func isProtocolAdvertisedOnOwnerThread(
        named interfaceName: String
    ) -> Bool {
        connection.preconditionIsOwnerThread()
        return connection.optionalGlobal(named: interfaceName) != nil
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

    package func presentationOnOwnerThread() throws -> RawPresentation {
        connection.preconditionIsOwnerThread()
        let globals = try connection.bindRequiredGlobals()
        guard case .bound(let presentation) = globals.extensions.presentation else {
            throw ClientError.display(.presentationTimeUnavailable)
        }

        return presentation
    }

    package func outputIDForPresentationSyncOutput(
        _ output: RawOutputPointerIdentity
    ) throws -> OutputID? {
        connection.preconditionIsOwnerThread()
        guard
            let rawID = try connection.bindRequiredGlobals()
                .outputRegistry.outputID(for: output)
        else {
            return nil
        }

        return OutputID(rawID)
    }

    @discardableResult
    package func setPointerCursorOnOwnerThread(
        _ cursor: PointerCursor
    ) throws -> [CursorRequestResult] {
        connection.preconditionIsOwnerThread()
        return try inputCoordinator.setPointerCursor(cursor)
    }

    package func updateCursorOutputScalesOnOwnerThread(
        surfaceID: RawObjectID,
        outputIDs: [OutputID]
    ) throws {
        connection.preconditionIsOwnerThread()
        guard let outputRegistry = connection.boundGlobals?.outputRegistry else { return }

        try inputCoordinator.updateCursorOutputScales(
            surfaceID: surfaceID,
            focusedOutputs: outputScales(for: outputIDs, outputRegistry: outputRegistry),
            availableOutputs: outputRegistry.snapshots.map(CursorOutputScale.init)
        )
    }

    package func updateAvailableCursorOutputScalesOnOwnerThread() throws {
        connection.preconditionIsOwnerThread()
        guard let outputRegistry = connection.boundGlobals?.outputRegistry else { return }

        try inputCoordinator.updateAvailableCursorOutputScales(
            availableOutputs: outputRegistry.snapshots.map(CursorOutputScale.init)
        )
    }

    package func drainInputEventsOnOwnerThread() -> [InputEvent] {
        connection.preconditionIsOwnerThread()
        processPendingSessionInputEvents()

        return inputCoordinator.drainInputEvents()
    }

    package func drainDataTransferEventsOnOwnerThread() -> [DataTransferEvent] {
        connection.preconditionIsOwnerThread()
        let events = dataTransferEventQueue.drain()
        cancelSourceWrites(for: events)
        return events
    }

    package func drainDataTransferEventsAndDiagnosticsOnOwnerThread() -> DataTransferDrain {
        connection.preconditionIsOwnerThread()
        return Self.drainDataTransferEventsAndDiagnostics(
            dataTransferEventQueue.drain(),
            using: dataTransferSourceWriter,
            pendingDiagnostics: &pendingDataTransferDiagnostics
        )
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

        inputCoordinator.registerWindow(windowID: windowID, surfaceID: surfaceID)
        window.onClose = { [inputCoordinator, pointerCaptureManager] in
            pointerCaptureManager.removeSurface(surfaceID)
            inputCoordinator.unregisterSurface(surfaceID)
        }

        return window
    }

    private func allocateWindowID() -> WindowID {
        connection.preconditionIsOwnerThread()
        return windowIDs.next()
    }

    private func allocatePopupID() -> PopupID {
        connection.preconditionIsOwnerThread()
        return popupIDs.next()
    }

    private func processPendingRawInputEvents() throws {
        try processInputDataTransferState()
        processPendingSessionInputEvents()
    }

    private func processPendingSessionInputEvents() {
        let rawEvents = connection.drainInputEvents()

        inputCoordinator.processPendingSessionInputEvents(
            from: rawEvents,
            pointerConstraintLifecycleEvent: { [pointerCaptureManager] event in
                pointerCaptureManager.processRawInputEvent(event)
            },
            onSeatRemoved: { [textInputManager, pointerCaptureManager] seatID in
                textInputManager.removeSeat(seatID)
                pointerCaptureManager.removeSeat(seatID)
            },
            onPointerCapabilityLost: { [pointerCaptureManager] seatID in
                pointerCaptureManager.removePointerCapability(seatID)
            }
        )
    }

    private func outputScales(
        for outputIDs: [OutputID],
        outputRegistry: OutputRegistry
    ) -> [CursorOutputScale] {
        outputIDs.compactMap { outputID in
            outputRegistry.output(for: RawOutputID(outputID))
                .map(\.snapshot)
                .map(CursorOutputScale.init)
        }
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

        try inputCoordinator.registerPopup(
            popupID: popup.id,
            parentSurfaceID: parentWindow.surfaceID,
            surfaceID: popupSurfaceID
        )
        try updateCursorOutputScalesOnOwnerThread(
            surfaceID: popupSurfaceID,
            outputIDs: parentWindow.currentOutputIDsOnOwnerThread()
        )
        popup.onClose = { [inputCoordinator, pointerCaptureManager] in
            pointerCaptureManager.removeSurface(popupSurfaceID)
            inputCoordinator.unregisterSurface(popupSurfaceID)
        }

        return popup
    }
}
