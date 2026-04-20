import Glibc
import Testing

@testable import WaylandRaw

@Suite
struct EventLoopSmokeTests {
    @Test
    func eventLoopPumpOnceIsCallable() {
        // Verify the EventLoop API compiles and is accessible.
        // Actual socket-level behavior requires a live compositor.
        _ = EventLoop.pumpOnce as (OpaquePointer, Int32) throws -> Void
    }

    @Test
    func eventLoopRunIsCallable() {
        _ = EventLoop.run as (OpaquePointer, () -> Bool) throws -> Void
    }

    @Test
    func eventLoopRetriesFlushInterruptedBySignal() throws {
        let display = OpaquePointer(bitPattern: 1)!
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
            makeDisplayError: { _, fallbackErrno in .systemError(errno: fallbackErrno ?? 0) }
        )

        try EventLoop.pumpOnce(
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
        let display = OpaquePointer(bitPattern: 1)!
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
            makeDisplayError: { _, fallbackErrno in .systemError(errno: fallbackErrno ?? 0) }
        )

        try EventLoop.pumpOnce(
            display: display,
            timeoutMilliseconds: 0,
            operations: operations
        )

        #expect(flushCallCount == 2)
        #expect(polledEvents == Int16(POLLIN) | Int16(POLLOUT))
        #expect(cancelReadCallCount == 1)
    }

    @Test
    func eventLoopThrowsWhenPollReportsFailureEvent() {
        let display = OpaquePointer(bitPattern: 1)!
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
            makeDisplayError: { _, fallbackErrno in .systemError(errno: fallbackErrno ?? 0) }
        )

        do {
            try EventLoop.pumpOnce(
                display: display,
                timeoutMilliseconds: 0,
                operations: operations
            )
            Issue.record("Expected poll failure event to throw.")
        } catch RuntimeError.pollEventFailed(let revents) {
            #expect(revents & Int16(POLLHUP) != 0)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(cancelReadCallCount == 1)
    }

    @Test
    func eventLoopThrowsWhenPrepareReadFailsUnexpectedly() {
        let display = OpaquePointer(bitPattern: 1)!
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
            makeDisplayError: { _, fallbackErrno in .systemError(errno: fallbackErrno ?? 0) }
        )

        do {
            try EventLoop.pumpOnce(
                display: display,
                timeoutMilliseconds: 0,
                operations: operations
            )
            Issue.record("Expected unexpected prepare-read failure to throw.")
        } catch RuntimeError.systemError(let errorCode) {
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
            .syncRequestFailed,
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
    func missingGlobalErrorIncludesInterfaceName() {
        let error = RuntimeError.missingRequiredGlobal("xdg_wm_base")
        #expect(error.description.contains("xdg_wm_base"))
    }
}
