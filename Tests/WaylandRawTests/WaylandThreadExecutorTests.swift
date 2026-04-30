import Glibc
import Synchronization
import Testing

@testable import WaylandRaw
@testable import WaylandRawUnsafeShim

private actor ExecutorProbe {
    private let executor: WaylandThreadExecutor

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }

    init(executor probeExecutor: WaylandThreadExecutor) {
        executor = probeExecutor
    }

    func isRunningOnExecutorThread() -> Bool {
        executor.isOwnerThread
    }
}

private final class EventSourceProbe: WaylandThreadEventSource, Sendable {
    private struct State: Sendable {
        var isClosed = false
        var pollCount = 0
        var didRunOnOwnerThread = false
    }

    private let executor: WaylandThreadExecutor
    private let state = Mutex(State())

    init(executor sourceExecutor: WaylandThreadExecutor) {
        executor = sourceExecutor
    }

    var isClosed: Bool {
        state.withLock { $0.isClosed }
    }

    func fileDescriptor() throws -> CInt {
        executor.wakeFileDescriptor
    }

    func dispatchPending() throws -> Int32 {
        0
    }

    func prepareRead() throws -> Bool {
        true
    }

    func flush() throws -> Bool {
        false
    }

    func readEvents() throws {
        let didRunOnOwnerThread = executor.isOwnerThread
        state.withLock { state in
            state.pollCount += 1
            state.didRunOnOwnerThread = didRunOnOwnerThread
            state.isClosed = true
        }
    }

    func cancelRead() {
        // Test source reaches readEvents through the wake fd path.
    }

    func handleEventLoopError(_: any Error) {
        // Test source never throws from event-loop phases.
    }

    func snapshot() -> (pollCount: Int, didRunOnOwnerThread: Bool) {
        state.withLock { ($0.pollCount, $0.didRunOnOwnerThread) }
    }
}

private final class FailingReadEventSourceProbe: WaylandThreadEventSource, Sendable {
    private struct State: Sendable {
        var readEventsCallCount = 0
        var cancelReadCallCount = 0
        var eventLoopErrorCount = 0
    }

    private let executor: WaylandThreadExecutor
    private let state = Mutex(State())

    init(executor sourceExecutor: WaylandThreadExecutor) {
        executor = sourceExecutor
    }

    var isClosed: Bool {
        state.withLock { $0.eventLoopErrorCount > 0 }
    }

    func fileDescriptor() throws -> CInt {
        executor.wakeFileDescriptor
    }

    func dispatchPending() throws -> Int32 {
        0
    }

    func prepareRead() throws -> Bool {
        true
    }

    func flush() throws -> Bool {
        false
    }

    func readEvents() throws {
        state.withLock { $0.readEventsCallCount += 1 }
        throw RuntimeError.systemError(errno: EPIPE)
    }

    func cancelRead() {
        state.withLock { $0.cancelReadCallCount += 1 }
    }

    func handleEventLoopError(_: any Error) {
        state.withLock { $0.eventLoopErrorCount += 1 }
    }

    func snapshot() -> (
        readEventsCallCount: Int,
        cancelReadCallCount: Int,
        eventLoopErrorCount: Int
    ) {
        state.withLock { state in
            (
                state.readEventsCallCount,
                state.cancelReadCallCount,
                state.eventLoopErrorCount
            )
        }
    }
}

@Suite
struct WaylandThreadExecutorTests {
    @Test
    func threadCreationFailureClosesWakeFileDescriptor() throws {
        let closedDescriptors = Mutex<[CInt]>([])
        let testingWakeFileDescriptor: CInt = 42

        #expect(throws: WaylandThreadExecutorError.threadCreationFailed(EAGAIN)) {
            _ = try WaylandThreadExecutor(
                forcingThreadCreationFailureForTesting: EAGAIN,
                wakeFileDescriptorForTesting: testingWakeFileDescriptor
            ) { descriptor in
                closedDescriptors.withLock { descriptors in
                    descriptors.append(descriptor)
                }
                return 0
            }
        }

        #expect(closedDescriptors.withLock { $0 } == [testingWakeFileDescriptor])
    }

    @Test
    func wakeFileDescriptorSignalReportsBadDescriptor() {
        #expect(throws: WaylandThreadExecutorError.wakeFileDescriptorWriteFailed(EBADF)) {
            _ = try WaylandThreadExecutor.signalWakeFileDescriptor(-1)
        }
    }

    @Test
    func wakeFileDescriptorDrainReportsBadDescriptor() {
        #expect(throws: WaylandThreadExecutorError.wakeFileDescriptorReadFailed(EBADF)) {
            try WaylandThreadExecutor.drainWakeFileDescriptor(-1)
        }
    }

    @Test
    func syncRunsOperationOnOwnerThread() throws {
        let executor = try WaylandThreadExecutor()
        defer { executor.shutdown() }

        let isOwnerThread = try executor.sync {
            executor.isOwnerThread
        }

        #expect(isOwnerThread)
    }

    @Test
    func actorJobsRunOnOwnerThread() async throws {
        let executor = try WaylandThreadExecutor()
        defer { executor.shutdown() }
        let probe = ExecutorProbe(executor: executor)

        let isOwnerThread = await probe.isRunningOnExecutorThread()

        #expect(isOwnerThread)
    }

    @Test
    func installedEventSourceRunsInsideExecutorLoop() throws {
        let executor = try WaylandThreadExecutor()
        defer { executor.shutdown() }
        let source = EventSourceProbe(executor: executor)

        try executor.sync {
            try executor.installEventSource(source)
        }

        for _ in 0..<100 {
            let snapshot = source.snapshot()
            if snapshot.pollCount > 0 {
                #expect(snapshot.didRunOnOwnerThread)
                return
            }

            usleep(10_000)
        }

        #expect(Bool(false), "installed event source was not polled")
    }

    @Test
    func readEventFailureDoesNotCancelResolvedReadIntent() throws {
        let executor = try WaylandThreadExecutor()
        defer { executor.shutdown() }
        let source = FailingReadEventSourceProbe(executor: executor)

        try executor.sync {
            try executor.installEventSource(source)
        }

        for _ in 0..<100 {
            let snapshot = source.snapshot()
            if snapshot.eventLoopErrorCount > 0 {
                #expect(snapshot.readEventsCallCount == 1)
                #expect(snapshot.cancelReadCallCount == 0)
                return
            }

            usleep(10_000)
        }

        #expect(Bool(false), "failing event source was not polled")
    }
}
