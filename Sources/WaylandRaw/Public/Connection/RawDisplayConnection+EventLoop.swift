import CWaylandClientSystem
import CWaylandProtocols

extension RawDisplayConnection {
    package var eventLoopFileDescriptor: CInt {
        preconditionIsOwnerThread()
        return unsafe EventLoop.fileDescriptor(display: display.opaquePointer)
    }

    package func dispatchPendingEvents() throws -> Int32 {
        preconditionIsOwnerThread()
        return try unsafe QueueEventLoop.dispatchPending(
            display: display.opaquePointer,
            eventQueue: eventQueue.opaquePointer
        )
    }

    package func prepareReadEvents() throws -> Bool {
        preconditionIsOwnerThread()
        return try unsafe QueueEventLoop.prepareRead(
            display: display.opaquePointer,
            eventQueue: eventQueue.opaquePointer
        )
    }

    package func flushForExternalEventLoop() throws -> Bool {
        preconditionIsOwnerThread()
        return try unsafe EventLoop.flushForExternalPoll(display: display.opaquePointer)
    }

    package func readEvents() throws {
        preconditionIsOwnerThread()
        try unsafe EventLoop.readEvents(display: display.opaquePointer)
    }

    package func cancelReadEvents() {
        preconditionIsOwnerThread()
        unsafe EventLoop.cancelRead(display: display.opaquePointer)
    }

    package func pumpEvents(
        timeoutMilliseconds: Int32,
        wakeFileDescriptor: CInt,
        drainWakeFileDescriptor: @escaping () -> Void
    ) throws {
        preconditionIsOwnerThread()
        try unsafe QueueEventLoop.pumpOnce(
            display: display.opaquePointer,
            eventQueue: eventQueue.opaquePointer,
            timeoutMilliseconds: timeoutMilliseconds,
            wakeFileDescriptor: wakeFileDescriptor,
            drainWakeFileDescriptor: drainWakeFileDescriptor
        )
    }

    @available(
        *,
        noasync,
        message: "Run discovery from the owner-thread Wayland loop."
    )
    package func completeInitialDiscovery(
        timeoutMilliseconds: Int32 = defaultDiscoveryTimeoutMS
    ) throws {
        preconditionIsOwnerThread()
        guard timeoutMilliseconds >= 0 else {
            throw RuntimeError.operationTimedOut(
                "initial discovery timeout must be greater than or equal to zero"
            )
        }

        let wrappedDisplay = try createDisplayWrapperOnEventQueue()
        guard let syncCallback = unsafe swl_display_sync(wrappedDisplay) else {
            unsafe swl_display_wrapper_destroy(wrappedDisplay)
            throw RuntimeError.displaySyncRequestFailed
        }
        unsafe swl_display_wrapper_destroy(wrappedDisplay)
        do {
            _ = try proxyAdoption.adopt(syncCallback, interface: "wl_callback")
        } catch {
            unsafe swl_callback_destroy(syncCallback)
            throw error
        }

        var didFire = false
        let deadline = try rawMonotonicMilliseconds() + Int64(timeoutMilliseconds)
        let registration = try FrameCallbackRegistration(
            pointer: syncCallback,
            onDone: { didFire = true },
            invariantFailureSink: invariantFailureSink
        )

        try withExtendedLifetime(registration) {
            while !didFire {
                let remainingMilliseconds = deadline - (try rawMonotonicMilliseconds())
                guard remainingMilliseconds > 0 else {
                    throw RuntimeError.operationTimedOut("timed out waiting for initial globals")
                }

                let boundedRemaining = Int32(min(remainingMilliseconds, Int64(Int32.max)))
                try unsafe QueueEventLoop.pumpOnce(
                    display: display.opaquePointer,
                    eventQueue: eventQueue.opaquePointer,
                    timeoutMilliseconds: min(boundedRemaining, 50)
                )
            }
        }
        freezeStartupGlobals()
    }

    @safe
    private func createDisplayWrapperOnEventQueue() throws -> OpaquePointer {
        guard let wrappedDisplay = unsafe swl_display_create_wrapper(display.opaquePointer) else {
            throw RuntimeError.displayWrapperCreationFailed
        }
        unsafe swl_display_wrapper_set_queue(wrappedDisplay, eventQueue.opaquePointer)
        return unsafe wrappedDisplay
    }
}
