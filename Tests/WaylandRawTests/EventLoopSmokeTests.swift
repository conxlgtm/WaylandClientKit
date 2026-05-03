import Glibc
import Testing

@testable import WaylandRaw
@testable import WaylandRawUnsafeShim

@Suite
struct EventLoopSmokeTests {  // swiftlint:disable:this type_body_length
    @Test
    func eventLoopPumpOnceIsCallable() {
        // Verify the EventLoop API compiles and is accessible.
        // Actual socket-level behavior requires a live compositor.
        _ =
            UnsafeDefaultQueueEventLoop.pumpOnceDefaultQueueUnsafe
            as (OpaquePointer, Int32) throws -> Void
    }

    @Test
    func eventLoopRunIsCallable() {
        _ =
            UnsafeDefaultQueueEventLoop.runDefaultQueueUnsafe
            as (OpaquePointer, () -> Bool) throws -> Void
    }

    @Test
    func eventLoopRetriesFlushInterruptedBySignal() throws {
        let display = try makeDisplayPointer()
        var flushCallCount = 0
        var cancelReadCallCount = 0
        var polledEvents = Int16(0)

        let operations = EventLoopOperations(
            prepareRead: { _ in 0 },
            dispatchPending: { _ in 0 },
            flush: { _ in
                flushCallCount += 1
                if flushCallCount == 1 {
                    errno = EINTR
                    return -1
                }
                return 0
            },
            getFileDescriptor: { _ in 7 },
            pollFileDescriptor: { descriptor, _, _ in
                polledEvents = descriptor?.pointee.events ?? 0
                return 0
            },
            readEvents: { _ in 0 },
            cancelRead: { _ in cancelReadCallCount += 1 },
            makeDisplayError: { _, fallbackErrno in .displayError(errno: fallbackErrno ?? 0) }
        )

        try UnsafeDefaultQueueEventLoop.pumpOnce(
            display: display,
            timeoutMilliseconds: 0,
            operations: operations
        )

        #expect(flushCallCount == 2)
        #expect(polledEvents == Int16(POLLIN))
        #expect(cancelReadCallCount == 1)
    }

    @Test
    func eventLoopPollsForWritableAfterFlushWouldBlock() throws {
        let display = try makeDisplayPointer()
        var flushCallCount = 0
        var cancelReadCallCount = 0
        var polledEvents = Int16(0)

        let operations = EventLoopOperations(
            prepareRead: { _ in 0 },
            dispatchPending: { _ in 0 },
            flush: { _ in
                flushCallCount += 1
                if flushCallCount == 1 {
                    errno = EAGAIN
                    return -1
                }
                return 0
            },
            getFileDescriptor: { _ in 7 },
            pollFileDescriptor: { descriptor, _, _ in
                polledEvents = descriptor?.pointee.events ?? 0
                descriptor?.pointee.revents = Int16(POLLOUT)
                return 1
            },
            readEvents: { _ in 0 },
            cancelRead: { _ in cancelReadCallCount += 1 },
            makeDisplayError: { _, fallbackErrno in .displayError(errno: fallbackErrno ?? 0) }
        )

        try UnsafeDefaultQueueEventLoop.pumpOnce(
            display: display,
            timeoutMilliseconds: 0,
            operations: operations
        )

        #expect(flushCallCount == 2)
        #expect(polledEvents == Int16(POLLIN) | Int16(POLLOUT))
        #expect(cancelReadCallCount == 1)
    }

    @Test
    func eventLoopAttemptsReadAfterFlushPipeClosed() throws {
        let display = try makeDisplayPointer()
        var flushCallCount = 0
        var readEventsCallCount = 0
        var cancelReadCallCount = 0

        let operations = EventLoopOperations(
            prepareRead: { _ in 0 },
            dispatchPending: { _ in 0 },
            flush: { _ in
                flushCallCount += 1
                errno = EPIPE
                return -1
            },
            getFileDescriptor: { _ in 7 },
            pollFileDescriptor: { descriptor, _, _ in
                #expect(descriptor?.pointee.events == Int16(POLLIN))
                descriptor?.pointee.revents = Int16(POLLIN)
                return 1
            },
            readEvents: { _ in
                readEventsCallCount += 1
                return 0
            },
            cancelRead: { _ in cancelReadCallCount += 1 },
            makeDisplayError: { _, fallbackErrno in .displayError(errno: fallbackErrno ?? 0) }
        )

        try UnsafeDefaultQueueEventLoop.pumpOnce(
            display: display,
            timeoutMilliseconds: 0,
            operations: operations
        )

        #expect(flushCallCount == 1)
        #expect(readEventsCallCount == 1)
        #expect(cancelReadCallCount == 0)
    }

    @Test
    func eventLoopCancelsPreparedReadWhenWakeDescriptorFires() throws {
        let display = try makeDisplayPointer()
        var cancelReadCallCount = 0
        var readEventsCallCount = 0
        var drainWakeCallCount = 0

        let operations = EventLoopOperations(
            prepareRead: { _ in 0 },
            dispatchPending: { _ in 0 },
            flush: { _ in 0 },
            getFileDescriptor: { _ in 7 },
            pollFileDescriptor: { descriptors, count, _ in
                #expect(count == 2)
                descriptors?[0].revents = 0
                descriptors?[1].revents = Int16(POLLIN)
                return 1
            },
            readEvents: { _ in
                readEventsCallCount += 1
                return 0
            },
            cancelRead: { _ in cancelReadCallCount += 1 },
            makeDisplayError: { _, fallbackErrno in .displayError(errno: fallbackErrno ?? 0) }
        )

        try UnsafeDefaultQueueEventLoop.pumpOnce(
            display: display,
            timeoutMilliseconds: 0,
            operations: operations,
            wakeFileDescriptor: 8
        ) {
            drainWakeCallCount += 1
        }

        #expect(cancelReadCallCount == 1)
        #expect(readEventsCallCount == 0)
        #expect(drainWakeCallCount == 1)
    }

    @Test
    func eventLoopThrowsWhenPollReportsFailureEvent() throws {
        let display = try makeDisplayPointer()
        var cancelReadCallCount = 0

        let operations = EventLoopOperations(
            prepareRead: { _ in 0 },
            dispatchPending: { _ in 0 },
            flush: { _ in 0 },
            getFileDescriptor: { _ in 7 },
            pollFileDescriptor: { descriptor, _, _ in
                descriptor?.pointee.revents = Int16(POLLHUP)
                return 1
            },
            readEvents: { _ in 0 },
            cancelRead: { _ in cancelReadCallCount += 1 },
            makeDisplayError: { _, fallbackErrno in .displayError(errno: fallbackErrno ?? 0) }
        )

        do {
            try UnsafeDefaultQueueEventLoop.pumpOnce(
                display: display,
                timeoutMilliseconds: 0,
                operations: operations
            )
            Issue.record("Expected poll failure event to throw.")
        } catch UnsafeDefaultQueueEventLoopError.pollEventFailed(let revents) {
            #expect(revents & Int16(POLLHUP) != 0)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(cancelReadCallCount == 1)
    }

    @Test
    func eventLoopThrowsWhenPrepareReadFailsUnexpectedly() throws {
        let display = try makeDisplayPointer()
        var dispatchPendingCallCount = 0
        var cancelReadCallCount = 0

        let operations = EventLoopOperations(
            prepareRead: { _ in
                errno = EBADF
                return -1
            },
            dispatchPending: { _ in
                dispatchPendingCallCount += 1
                return 0
            },
            flush: { _ in 0 },
            getFileDescriptor: { _ in 7 },
            pollFileDescriptor: { _, _, _ in 0 },
            readEvents: { _ in 0 },
            cancelRead: { _ in cancelReadCallCount += 1 },
            makeDisplayError: { _, fallbackErrno in .displayError(errno: fallbackErrno ?? 0) }
        )

        do {
            try UnsafeDefaultQueueEventLoop.pumpOnce(
                display: display,
                timeoutMilliseconds: 0,
                operations: operations
            )
            Issue.record("Expected unexpected prepare-read failure to throw.")
        } catch UnsafeDefaultQueueEventLoopError.displayError(let errorCode) {
            #expect(errorCode == EBADF)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(dispatchPendingCallCount == 0)
        #expect(cancelReadCallCount == 0)
    }

    @Test
    func runtimeErrorDescriptionsAreNonEmpty() {
        let cases: [RuntimeError] = [
            .connectionFailed,
            .registryCreationFailed,
            .registryListenerInstallationFailed,
            .pointerListenerInstallationFailed,
            .keyboardListenerInstallationFailed,
            .touchListenerInstallationFailed,
            .displaySyncRequestFailed,
            .frameRequestFailed,
            .syncCallbackListenerInstallationFailed,
            .missingRequiredGlobal("wl_shm"),
            .bindFailed("wl_compositor"),
            .pollFailed(22),
            .pollEventFailed(revents: Int16(POLLHUP)),
            .systemError(errno: 5),
            .protocolError(interfaceName: "wl_surface", objectID: 3, code: 1),
            .protocolError(interfaceName: nil, objectID: 0, code: 0),
        ]

        for error in cases {
            #expect(!error.description.isEmpty)
        }
    }

    @Test
    func runtimeErrorProtocolErrorFormatsCorrectly() {
        let error = RuntimeError.protocolError(
            interfaceName: "wl_surface",
            objectID: 7,
            code: 3
        )
        #expect(error.description.contains("wl_surface"))
        #expect(error.description.contains("7"))
        #expect(error.description.contains("3"))
    }

    @Test
    func runtimeErrorProtocolErrorHandlesNilInterface() {
        let error = RuntimeError.protocolError(
            interfaceName: nil,
            objectID: 0,
            code: 0
        )
        #expect(error.description.contains("?"))
    }

    @Test
    func runtimeErrorSystemErrorCarriesStructuredPayload() {
        let error = RuntimeError.systemError(errno: 5)
        guard case .system(let systemError) = error else {
            Issue.record("Expected structured system error")
            return
        }

        #expect(systemError.errno == 5)
    }

    @Test
    func runtimeErrorProxyMismatchCarriesStructuredPayload() {
        let error = RuntimeError.proxyQueueMismatch("wl_surface")
        guard case .proxy(.queueMismatch(let interface, let objectID)) = error else {
            Issue.record("Expected structured proxy queue mismatch")
            return
        }

        #expect(interface == "wl_surface")
        #expect(objectID == nil)
    }

    @Test
    func missingGlobalErrorIncludesInterfaceName() {
        let error = RuntimeError.missingRequiredGlobal("xdg_wm_base")
        #expect(error.description.contains("xdg_wm_base"))
    }

    private func makeDisplayPointer() throws -> OpaquePointer {
        try #require(OpaquePointer(bitPattern: 1))
    }
}
