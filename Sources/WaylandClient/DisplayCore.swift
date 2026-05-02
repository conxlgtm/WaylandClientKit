import WaylandRaw

@safe
final class DisplayCore: RawInvariantFailureReporter, WindowFailureSink {
    private let eventHub: DisplayEventHub
    private var session: DisplaySession?
    private var windows: [WindowID: TopLevelWindow] = [:]
    private(set) var isClosed = false
    private var needsFatalFailureFinalization = false

    init(session activeSession: DisplaySession, eventHub displayEventHub: DisplayEventHub) {
        session = activeSession
        eventHub = displayEventHub
    }

    init(eventHub displayEventHub: DisplayEventHub) {
        session = nil
        eventHub = displayEventHub
    }

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

    func createTopLevelWindowID(
        configuration windowConfiguration: WindowConfiguration = .default
    ) throws -> WindowID {
        try withFatalFailureFinalization {
            let window = try requireSession().createTopLevelWindowOnOwnerThread(
                configuration: windowConfiguration,
                failureSink: WeakWindowFailureSink(self)
            )
            windows[window.id] = window
            guard !isClosed else {
                throw ClientError.displayClosed
            }
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
            publishInputEvents(session.drainInputEventsOnOwnerThread())
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
                throw ClientError.displayClosed
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
        windows.removeAll(keepingCapacity: false)
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
                    operation: .presentation("presentationFailed"),
                    message: error.description
                )
            )
        case .diagnostic(let diagnostic):
            eventHub.publishWindowDiagnostic(diagnostic)
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
            publishInputEvents(activeSession.drainInputEventsOnOwnerThread())
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
            publishInputEvents(activeSession.drainInputEventsOnOwnerThread())
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

    private func publishInputEvents(_ inputEvents: [InputEvent]) {
        for inputEvent in inputEvents {
            eventHub.publishInput(inputEvent)
        }
    }

    private func markDefunctForFatalFailure(_ error: WaylandDisplayError) {
        guard !isClosed else { return }
        // Raw invariant failures may be reported from inside a C callback, so
        // public streams fail immediately while destructive cleanup is deferred.
        isClosed = true
        needsFatalFailureFinalization = true
        eventHub.finish(throwing: error)
    }

    private func withFatalFailureFinalization<Result>(
        _ body: () throws -> Result
    ) rethrows -> Result {
        defer { finalizeFatalFailureAfterDispatch() }
        return try body()
    }

    private func finalizeFatalFailureAfterDispatch() {
        guard needsFatalFailureFinalization else { return }
        needsFatalFailureFinalization = false
        windows.removeAll(keepingCapacity: false)
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
        windows.removeValue(forKey: windowID)
        eventHub.publish(.windowClosed(windowID))
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

    private func requireOpenWindow(_ windowID: WindowID) throws -> TopLevelWindow {
        guard !isClosed else {
            throw ClientError.displayClosed
        }
        return try requireWindow(windowID)
    }
}
