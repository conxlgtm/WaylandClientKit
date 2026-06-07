// swiftlint:disable file_length

import WaylandRaw

@safe
final class DisplayCore: RawInvariantFailureReporter, WindowFailureSink {
    // swiftlint:disable:previous type_body_length
    let eventHub: DisplayEventHub
    private var lifecycle: DisplayCoreLifecycle
    private var isDiscardingSurfaceGraph = false
    var surfaces = DisplaySurfaceStore<TopLevelWindow, PopupRoleSurface>()
    var subsurfacesByID: [SubsurfaceID: SubsurfaceRoleSurface] = [:]
    var subsurfaceParentWindowIDs: [SubsurfaceID: WindowID] = [:]
    var subsurfaceIDsByParentWindow: [WindowID: [SubsurfaceID]] = [:]
    var closedSubsurfaceIDs: Set<SubsurfaceID> = []
    var idleInhibitorIDs = IDGenerator<IdleInhibitorID>()
    var idleInhibitorsByID: [IdleInhibitorID: DisplayIdleInhibitorRecord] = [:]
    var idleInhibitorIDsByWindowID: [WindowID: [IdleInhibitorID]] = [:]
    var closedIdleInhibitorIDs: Set<IdleInhibitorID> = []
    var isClosed: Bool { lifecycle.isClosed }
    var activeSession: DisplaySession? { lifecycle.activeSession }
    var hasPendingFatalFailure: Bool { lifecycle.hasPendingFatalFailure }

    init(session activeSession: DisplaySession, eventHub displayEventHub: DisplayEventHub) {
        lifecycle = .active(activeSession)
        eventHub = displayEventHub
    }

    init(eventHub displayEventHub: DisplayEventHub) {
        lifecycle = .testHarness
        eventHub = displayEventHub
    }

    func createTopLevelWindowID(
        configuration windowConfiguration: WindowConfiguration = .default
    ) throws -> WindowID {
        try withFatalFailureFinalization {
            let window = try requireSession().createTopLevelWindowOnOwnerThread(
                configuration: windowConfiguration,
                failureSink: WeakWindowFailureSink(self)
            )
            guard !isClosed else {
                window.closeOnOwnerThread()
                throw ClientError.display(.closed)
            }
            let surfaceID = SurfaceID(rawObjectID: window.surfaceID)
            do {
                try surfaces.insertWindow(window, surfaceID: surfaceID)
            } catch {
                window.closeOnOwnerThread()
                throw error
            }
            installEventCallbacks(for: window)
            try window.markPublishedOnOwnerThread()
            assertSurfaceStoreInvariants()
            return window.id
        }
    }

    // swiftlint:disable:next function_parameter_count
    func showWindow(
        _ windowID: WindowID,
        timeoutMilliseconds: Int32,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try withFatalFailureFinalization {
            let window = try requireOpenWindow(windowID)
            let presentationFeedback = try presentationFeedbackCommitRequest(
                for: window,
                windowID: windowID,
                isRequested: requestPresentationFeedback
            )
            try window.showOnOwnerThread(
                timeoutMilliseconds: timeoutMilliseconds,
                metadata: metadata,
                damage: damage,
                presentationFeedback: presentationFeedback,
                draw
            )
            guard !isClosed, let activeSession else { return }
            publishSessionEvents(activeSession)
        }
    }

    func redraw(
        _ windowID: WindowID,
        metadata: SurfaceCommitMetadata,
        requestPresentationFeedback: Bool,
        damage: SurfaceDamageRegion?,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try withFatalFailureFinalization {
            let window = try requireOpenWindow(windowID)
            let presentationFeedback = try presentationFeedbackCommitRequest(
                for: window,
                windowID: windowID,
                isRequested: requestPresentationFeedback
            )
            try window.redrawOnOwnerThread(
                metadata: metadata,
                damage: damage,
                presentationFeedback: presentationFeedback,
                draw
            )
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
        }
    }

    func setWindowInputRegion(_ windowID: WindowID, _ region: SurfaceRegion?) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).setInputRegionOnOwnerThread(region)
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
        }
    }

    func setWindowOpaqueRegion(_ windowID: WindowID, _ region: SurfaceRegion?) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).setOpaqueRegionOnOwnerThread(region)
            guard !isClosed else {
                throw ClientError.display(.closed)
            }
        }
    }

    func windowIsClosed(_ windowID: WindowID) throws -> Bool {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).isClosedOnOwnerThread
        }
    }

    func windowNeedsRedraw(_ windowID: WindowID) throws -> Bool {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).needsRedrawOnOwnerThread
        }
    }

    func windowDecorationMode(_ windowID: WindowID) throws -> WindowDecorationMode {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).decorationModeOnOwnerThread
        }
    }

    func windowGeometry(_ windowID: WindowID) throws -> SurfaceGeometry {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).geometryOnOwnerThread
        }
    }

    func requestRedraw(_ windowID: WindowID) throws {
        try withFatalFailureFinalization {
            try requireOpenWindow(windowID).requestRedrawOnOwnerThread()
        }
    }

    func capabilities() throws -> WaylandCapabilities {
        try withFatalFailureFinalization {
            try requireSession().capabilitiesOnOwnerThread()
        }
    }

    func outputs() throws -> [OutputSnapshot] {
        try withFatalFailureFinalization {
            try requireSession().outputSnapshotsOnOwnerThread()
        }
    }

    func closeWindow(_ windowID: WindowID) {
        withFatalFailureFinalization {
            // Fatal raw invariants already finished streams and deferred graph cleanup, so
            // avoid publishing orderly window lifecycle events on that explicit path.
            guard !hasPendingFatalFailure else { return }
            for inhibitorID in idleInhibitorIDsByWindowID[windowID] ?? [] {
                closeIdleInhibitor(inhibitorID)
            }
            for subsurfaceID in subsurfaceIDsTopDown(parentedBy: windowID) {
                closeSubsurface(subsurfaceID)
            }
            for popupID in popupIDsTopDown(parentedBy: windowID) {
                closePopup(popupID)
            }
            guard let window = surfaces.window(windowID) else { return }
            window.closeOnOwnerThread()
        }
    }

    func close() {
        guard !isClosed else { return }
        let session = activeSession
        for windowID in surfaces.allWindowIDs {
            closeWindow(windowID)
        }
        session?.releaseWaylandResourcesOnOwnerThread()
        lifecycle = .closed
        eventHub.finish()
        withExtendedLifetime(session) {
            _ = ()
        }
    }

    func fail(_ error: WaylandDisplayError) {
        guard !isClosed else { return }
        let session = activeSession
        // Non-callback failures can synchronously discard the owned graph.
        discardSurfaceGraphForFatalCleanup()
        session?.releaseWaylandResourcesOnOwnerThread()
        lifecycle = .closed
        eventHub.finish(throwing: error)
        assertSurfaceStoreInvariants()
        withExtendedLifetime(session) {
            _ = ()
        }
    }

    func withFatalFailureFinalization<Result: ~Copyable>(
        _ body: () throws -> Result
    ) rethrows -> Result {
        defer { finalizeFatalFailureAfterDispatch() }
        return try body()
    }

    private func finalizeFatalFailureAfterDispatch() {
        guard hasPendingFatalFailure else { return }
        discardSurfaceGraphForFatalCleanup()
        lifecycle = .closed
        assertSurfaceStoreInvariants()
    }

    private func discardSurfaceGraphForFatalCleanup() {
        isDiscardingSurfaceGraph = true
        defer { isDiscardingSurfaceGraph = false }

        var discardedSurfaces = DisplaySurfaceStore<TopLevelWindow, PopupRoleSurface>()
        swap(&surfaces, &discardedSurfaces)
        removeAllIdleInhibitors()
        removeAllSubsurfaces()
        discardedSurfaces.removeAll()
    }

    private func installEventCallbacks(for window: TopLevelWindow) {
        let windowID = window.id
        let surfaceID = window.surfaceID
        window.onCloseRequested = { [weak core = self] in
            core?.handleWindowCloseRequested(windowID)
        }
        window.onClosed = { [weak core = self] in
            core?.handleWindowClosed(windowID)
        }
        window.onRedrawRequested = { [weak core = self] in
            core?.publishWindowRedrawRequested(windowID)
        }
        window.onOutputMembershipChanged = { [weak core = self] outputs in
            core?.handleWindowOutputsChanged(
                windowID: windowID,
                surfaceID: surfaceID,
                outputs: outputs
            )
        }
    }

    func surfaceGraphAcceptsLifecycleCallback() -> Bool {
        !isClosed && !isDiscardingSurfaceGraph
    }

    private func publishWindowRedrawRequested(_ windowID: WindowID) {
        guard surfaceGraphAcceptsLifecycleCallback() else { return }
        eventHub.publish(.redrawRequested(windowID))
    }

    private func handleWindowOutputsChanged(
        windowID: WindowID,
        surfaceID: RawObjectID,
        outputs: [OutputID]
    ) {
        guard surfaceGraphAcceptsLifecycleCallback() else { return }
        do {
            try activeSession?.updateCursorOutputScalesOnOwnerThread(
                surfaceID: surfaceID,
                outputIDs: outputs
            )
        } catch {
            markSurfaceStoreInvariantFailed(error)
        }
        publishWindowOutputsChanged(windowID: windowID, outputs: outputs)
    }

    private func publishWindowOutputsChanged(
        windowID: WindowID,
        outputs: [OutputID]
    ) {
        guard surfaceGraphAcceptsLifecycleCallback() else { return }
        eventHub.publish(
            .windowOutputsChanged(
                WindowOutputMembershipEvent(windowID: windowID, outputs: outputs)
            )
        )
    }

    // swiftlint:disable:next large_tuple
    package func surfaceLifecycleCallbacksForTesting(windowID: WindowID) -> (
        closeRequested: () -> Void,
        closed: () -> Void,
        redrawRequested: () -> Void,
        outputsChanged: ([OutputID]) -> Void
    ) {
        (
            closeRequested: { [weak self] in
                self?.handleWindowCloseRequested(windowID)
            },
            closed: { [weak self] in
                self?.handleWindowClosed(windowID)
            },
            redrawRequested: { [weak self] in
                self?.publishWindowRedrawRequested(windowID)
            },
            outputsChanged: { [weak self] outputs in
                self?.publishWindowOutputsChanged(windowID: windowID, outputs: outputs)
            }
        )
    }

    package func withSurfaceGraphDiscardForTesting(_ body: () -> Void) {
        isDiscardingSurfaceGraph = true
        defer { isDiscardingSurfaceGraph = false }
        body()
    }

    private func handleWindowCloseRequested(_ windowID: WindowID) {
        guard surfaceGraphAcceptsLifecycleCallback() else { return }
        eventHub.publish(.windowCloseRequested(windowID))
    }

    private func handleWindowClosed(_ windowID: WindowID) {
        guard surfaceGraphAcceptsLifecycleCallback() else { return }
        for subsurfaceID in subsurfaceIDsTopDown(parentedBy: windowID) {
            closeSubsurface(subsurfaceID)
        }
        for popupID in popupIDsTopDown(parentedBy: windowID) {
            closePopup(popupID)
        }
        do {
            try surfaces.removeWindow(windowID)
        } catch {
            markSurfaceStoreInvariantFailed(error)
            return
        }
        eventHub.publish(.windowClosed(windowID))
        assertSurfaceStoreInvariants()
    }

    func requireSession() throws -> DisplaySession {
        guard let session = activeSession else {
            throw ClientError.display(.closed)
        }
        return session
    }

    private func requireWindow(_ windowID: WindowID) throws -> TopLevelWindow {
        guard let window = surfaces.window(windowID) else {
            throw ClientError.display(.unknownWindow(windowID))
        }
        return window
    }

    func requireOpenWindow(_ windowID: WindowID) throws -> TopLevelWindow {
        guard !isClosed else {
            throw ClientError.display(.closed)
        }
        return try requireWindow(windowID)
    }

    func requirePopup(_ popupID: PopupID) throws -> PopupRoleSurface {
        guard !surfaces.popupIsClosedOrClosing(popupID) else {
            throw ClientError.display(.closedPopup)
        }
        guard let popup = surfaces.popup(popupID) else {
            throw ClientError.display(.unknownPopup)
        }
        return popup
    }

    func requireOpenPopup(_ popupID: PopupID) throws -> PopupRoleSurface {
        guard !isClosed else {
            throw ClientError.display(.closed)
        }
        let popup = try requirePopup(popupID)
        guard !popup.isClosedOnOwnerThread else {
            throw ClientError.display(.closedPopup)
        }
        return popup
    }
}

private enum DisplayCoreLifecycle {
    case testHarness
    case active(DisplaySession)
    case failedPendingFinalization(DisplaySession?)
    case closed

    var isClosed: Bool {
        switch self {
        case .testHarness, .active:
            false
        case .failedPendingFinalization, .closed:
            true
        }
    }

    var hasPendingFatalFailure: Bool {
        switch self {
        case .failedPendingFinalization:
            true
        case .testHarness, .active, .closed:
            false
        }
    }

    var activeSession: DisplaySession? {
        switch self {
        case .active(let session):
            session
        case .testHarness, .failedPendingFinalization, .closed:
            nil
        }
    }
}

extension DisplayCore {
    func reportFatalRawInvariantFailure(_ failure: RawInvariantFailure) {
        markDefunctForFatalFailure(.internalInvariantViolation(.message(failure.description)))
    }

    func reportWindowFailure(_ failure: WindowFailure) {
        switch failure {
        case .internalInvariant(let invariant):
            markDefunctForFatalFailure(.internalInvariantViolation(invariant))
        case .protocolViolation(let error):
            markDefunctForFatalFailure(.protocolError(error))
        case .lifecycleViolation(let windowID, let transition):
            markDefunctForFatalFailure(
                .internalInvariantViolation(
                    .invalidWindowTransition(windowID, transition: transition)
                )
            )
        case .presentationFailure(let windowID, let error):
            eventHub.publishWindowDiagnostic(
                WindowDiagnostic(
                    windowID: windowID,
                    payload: .presentation(
                        WindowPresentationDiagnostic(
                            operation: .presentationFailed,
                            error: error
                        )
                    )
                )
            )
        case .diagnostic(let diagnostic):
            eventHub.publishWindowDiagnostic(diagnostic)
        }
    }

    func markDefunctForFatalFailure(_ error: WaylandDisplayError) {
        guard !isClosed else { return }
        // Raw invariant failures may be reported from inside a C callback, so
        // public streams fail immediately while destructive cleanup is deferred.
        lifecycle = .failedPendingFinalization(activeSession)
        eventHub.finish(throwing: error)
    }
}

extension DisplayCore {
    func currentPointerCursor() throws -> PointerCursor {
        try withFatalFailureFinalization {
            try requireSession().pointerCursorOnOwnerThread
        }
    }

    @discardableResult
    func setPointerCursor(_ cursor: PointerCursor) throws -> [CursorRequestResult] {
        try withFatalFailureFinalization {
            try requireSession().setPointerCursorOnOwnerThread(cursor)
        }
    }

    func fileDescriptor() throws -> CInt {
        try requireSession().eventLoopFileDescriptorOnOwnerThread
    }

    @discardableResult
    func dispatchPending() throws -> Int32 {
        try withFatalFailureFinalization {
            guard !isClosed else { return 0 }
            let activeSession = try requireSession()
            let dispatchedCount = try activeSession.dispatchPendingEventsOnOwnerThread()
            guard !isClosed else { return dispatchedCount }
            publishSessionEvents(activeSession)
            return dispatchedCount
        }
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
        try withFatalFailureFinalization {
            guard !isClosed else { return }
            try requireSession().readEventsOnOwnerThread()
        }
    }

    func cancelRead() {
        guard let activeSession else { return }
        activeSession.cancelReadEventsOnOwnerThread()
    }
}
