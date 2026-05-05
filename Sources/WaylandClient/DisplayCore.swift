import WaylandRaw

@safe
final class DisplayCore: RawInvariantFailureReporter, WindowFailureSink {
    let eventHub: DisplayEventHub
    var session: DisplaySession?
    private var windows: [WindowID: TopLevelWindow] = [:]
    var popups: [PopupID: PopupRoleSurface] = [:]
    var surfaceGraph = SurfaceGraph()
    var windowSurfaceIDs: [WindowID: SurfaceID] = [:]
    var popupSurfaceIDs: [PopupID: SurfaceID] = [:]
    var popupParentWindowIDs: [PopupID: WindowID] = [:]
    var closedPopupIDs: Set<PopupID> = []
    private(set) var isClosed = false
    var needsFatalFailureFinalization = false

    init(session activeSession: DisplaySession, eventHub displayEventHub: DisplayEventHub) {
        session = activeSession
        eventHub = displayEventHub
    }

    init(eventHub displayEventHub: DisplayEventHub) {
        session = nil
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
                try surfaceGraph.registerTopLevel(surfaceID: surfaceID, windowID: window.id)
            } catch {
                window.closeOnOwnerThread()
                throw error
            }
            windows[window.id] = window
            windowSurfaceIDs[window.id] = surfaceID
            installEventCallbacks(for: window)
            window.markPublishedOnOwnerThread()
            return window.id
        }
    }

    func showWindow(
        _ windowID: WindowID,
        timeoutMilliseconds: Int32,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try withFatalFailureFinalization {
            let window = try requireOpenWindow(windowID)
            try window.showOnOwnerThread(timeoutMilliseconds: timeoutMilliseconds, draw)
            guard !isClosed, let session else { return }
            publishSessionEvents(session)
        }
    }

    func redraw(
        _ windowID: WindowID,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) throws {
        try withFatalFailureFinalization {
            let window = try requireOpenWindow(windowID)
            try window.redrawOnOwnerThread(draw)
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

    func closeWindow(_ windowID: WindowID) {
        withFatalFailureFinalization {
            // Fatal raw invariants already finished streams and deferred graph cleanup;
            // avoid publishing orderly window lifecycle events on that explicit path.
            guard !needsFatalFailureFinalization else { return }
            for popupID in popupIDsTopDown(parentedBy: windowID) {
                closePopup(popupID)
            }
            guard let window = windows[windowID] else { return }
            window.closeOnOwnerThread()
        }
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
        // Non-callback failures can synchronously discard the owned graph.
        isClosed = true
        popups.removeAll(keepingCapacity: false)
        windows.removeAll(keepingCapacity: false)
        popupSurfaceIDs.removeAll(keepingCapacity: false)
        popupParentWindowIDs.removeAll(keepingCapacity: false)
        closedPopupIDs.removeAll(keepingCapacity: false)
        windowSurfaceIDs.removeAll(keepingCapacity: false)
        surfaceGraph = SurfaceGraph()
        session = nil
        eventHub.finish(throwing: error)
    }

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
                    operation: .presentation(.presentationFailed),
                    message: error.description
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
        isClosed = true
        needsFatalFailureFinalization = true
        eventHub.finish(throwing: error)
    }

    func withFatalFailureFinalization<Result: ~Copyable>(
        _ body: () throws -> Result
    ) rethrows -> Result {
        defer { finalizeFatalFailureAfterDispatch() }
        return try body()
    }

    private func finalizeFatalFailureAfterDispatch() {
        guard needsFatalFailureFinalization else { return }
        needsFatalFailureFinalization = false
        popups.removeAll(keepingCapacity: false)
        windows.removeAll(keepingCapacity: false)
        popupSurfaceIDs.removeAll(keepingCapacity: false)
        popupParentWindowIDs.removeAll(keepingCapacity: false)
        closedPopupIDs.removeAll(keepingCapacity: false)
        windowSurfaceIDs.removeAll(keepingCapacity: false)
        surfaceGraph = SurfaceGraph()
        session = nil
    }

    private func installEventCallbacks(for window: TopLevelWindow) {
        let windowID = window.id
        window.onCloseRequested = { [weak core = self] in
            core?.handleWindowCloseRequested(windowID)
        }
        window.onClosed = { [weak core = self] in
            core?.handleWindowClosed(windowID)
        }
        window.onRedrawRequested = { [weak core = self] in
            core?.eventHub.publish(.redrawRequested(windowID))
        }
    }

    private func handleWindowCloseRequested(_ windowID: WindowID) {
        eventHub.publish(.windowCloseRequested(windowID))
    }

    private func handleWindowClosed(_ windowID: WindowID) {
        for popupID in popupIDsTopDown(parentedBy: windowID) {
            closePopup(popupID)
        }
        if let surfaceID = windowSurfaceIDs.removeValue(forKey: windowID) {
            do {
                try surfaceGraph.unregisterTopLevel(surfaceID)
            } catch {
                markSurfaceGraphInvariantFailed(error)
                return
            }
        }
        windows.removeValue(forKey: windowID)
        eventHub.publish(.windowClosed(windowID))
    }

    func requireSession() throws -> DisplaySession {
        guard let session, !isClosed else {
            throw ClientError.display(.closed)
        }
        return session
    }

    private func requireWindow(_ windowID: WindowID) throws -> TopLevelWindow {
        guard let window = windows[windowID] else {
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
        guard !closedPopupIDs.contains(popupID) else {
            throw ClientError.display(.closedPopup)
        }
        guard let popup = popups[popupID] else {
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

extension DisplayCore {
    func clipboardOffer(for seatID: SeatID) throws -> DataOfferSnapshot? {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let offer = try activeSession.clipboardOfferOnOwnerThread(for: seatID)
            publishDataTransferEvents(activeSession.drainDataTransferEventsOnOwnerThread())
            return offer
        }
    }

    func receiveClipboardOffer(
        id offerID: DataOfferID,
        mimeType: MIMEType
    ) throws -> OwnedFileDescriptor {
        try withFatalFailureFinalization {
            let activeSession = try requireSession()
            let descriptor = try activeSession.receiveClipboardOfferOnOwnerThread(
                id: offerID,
                mimeType: mimeType
            )
            publishDataTransferEvents(activeSession.drainDataTransferEventsOnOwnerThread())
            return descriptor
        }
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

    func pumpOnce(
        timeoutMilliseconds: Int32,
        wakeFileDescriptor: CInt,
        drainWakeFileDescriptor: @escaping () -> Void
    ) throws {
        try withFatalFailureFinalization {
            guard !isClosed else { return }
            let activeSession = try requireSession()
            try activeSession.pumpEventsOnOwnerThread(
                timeoutMilliseconds: timeoutMilliseconds,
                wakeFileDescriptor: wakeFileDescriptor,
                drainWakeFileDescriptor: drainWakeFileDescriptor
            )
            guard !isClosed else { return }
            publishSessionEvents(activeSession)
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
        guard !isClosed, let session else { return }
        session.cancelReadEventsOnOwnerThread()
    }
}
