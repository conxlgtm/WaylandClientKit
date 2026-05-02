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

private final class OwnerThreadGate: Sendable {
    private struct State: Sendable {
        var didEnter = false
        var isOpen = false
    }

    private let state = Mutex(State())

    func enterAndWaitUntilOpened() {
        state.withLock { $0.didEnter = true }

        while !state.withLock({ $0.isOpen }) {
            usleep(1_000)
        }
    }

    func waitUntilEntered() -> Bool {
        for _ in 0..<1_000 {
            if state.withLock({ $0.didEnter }) {
                return true
            }

            usleep(1_000)
        }

        return false
    }

    func open() {
        state.withLock { $0.isOpen = true }
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
    func syncBootstrapOnlyRunsOperationOnOwnerThread() throws {
        let executor = try WaylandThreadExecutor()
        defer { executor.shutdown() }

        let isOwnerThread = try executor.syncBootstrapOnly {
            executor.isOwnerThread
        }

        #expect(isOwnerThread)
    }

    @Test
    func shutdownDrainsQueuedOperationsAndJoinsOwnerThread() throws {
        let executor = try WaylandThreadExecutor()
        let gate = OwnerThreadGate()
        defer {
            gate.open()
            executor.shutdown()
        }

        try executor.enqueueOperationForTesting {
            gate.enterAndWaitUntilOpened()
        }

        #expect(gate.waitUntilEntered())

        let operationRunCount = Mutex(0)
        try executor.enqueueOperationForTesting {
            operationRunCount.withLock { $0 += 1 }
        }
        try executor.enqueueOperationForTesting {
            operationRunCount.withLock { $0 += 1 }
        }

        let queued = executor.lifecycleSnapshotForTesting
        #expect(queued.state == .running)
        #expect(queued.hasThreadStarted)
        #expect(!queued.loopHasExited)
        #expect(!queued.hasJoinedThread)
        #expect(queued.queuedJobCount == 0)
        #expect(queued.queuedOperationCount == 2)

        gate.open()
        executor.shutdown()

        let stopped = executor.lifecycleSnapshotForTesting
        #expect(stopped.state == .joined(.orderly))
        #expect(stopped.hasThreadStarted)
        #expect(stopped.loopHasExited)
        #expect(stopped.hasJoinedThread)
        #expect(stopped.queuedJobCount == 0)
        #expect(stopped.queuedOperationCount == 0)
        #expect(stopped.acceptedOperationCount == 3)
        #expect(stopped.completedOperationCount == 3)
        #expect(operationRunCount.withLock { $0 } == 2)
    }

    @Test
    func shutdownModeUpgradesToAbandonWaylandSources() throws {
        let executor = try WaylandThreadExecutor()
        let gate = OwnerThreadGate()
        defer {
            gate.open()
            executor.shutdown(.abandonWaylandSources)
        }

        try executor.enqueueOperationForTesting {
            gate.enterAndWaitUntilOpened()
        }
        #expect(gate.waitUntilEntered())

        executor.requestStopAfterCurrentJob()
        var stopping = executor.lifecycleSnapshotForTesting
        #expect(stopping.state == .stopRequested(.orderly))

        executor.requestStopAfterCurrentJob(.abandonWaylandSources)
        stopping = executor.lifecycleSnapshotForTesting
        #expect(stopping.state == .stopRequested(.abandonWaylandSources))

        #expect(throws: WaylandThreadExecutorError.executorStopping(.abandonWaylandSources)) {
            try executor.enqueueOperationForTesting {
                Issue.record("operation should not be accepted while executor is stopping")
            }
        }

        gate.open()
        executor.shutdown(.abandonWaylandSources)

        let stopped = executor.lifecycleSnapshotForTesting
        #expect(stopped.state == .joined(.abandonWaylandSources))
        #expect(stopped.hasJoinedThread)
    }

    @Test
    func installEventSourceAfterStopReturnsStoppingError() throws {
        let executor = try WaylandThreadExecutor()
        let gate = OwnerThreadGate()
        defer {
            gate.open()
            executor.shutdown()
        }

        try executor.enqueueOperationForTesting {
            gate.enterAndWaitUntilOpened()
        }
        #expect(gate.waitUntilEntered())

        executor.requestStopAfterCurrentJob()

        #expect(throws: WaylandThreadExecutorError.executorStopping(.orderly)) {
            try executor.installEventSource(EventSourceProbe(executor: executor))
        }
    }

    @Test
    func enqueueOperationAfterShutdownReturnsStoppedError() throws {
        let executor = try WaylandThreadExecutor()
        executor.shutdown()

        #expect(throws: WaylandThreadExecutorError.executorStopped) {
            try executor.enqueueOperationForTesting {
                Issue.record("operation should not be accepted after executor shutdown")
            }
        }
    }

    @Test
    func requestStopAfterJoinedDoesNotRewriteShutdownMode() throws {
        let executor = try WaylandThreadExecutor()
        executor.shutdown()

        executor.requestStopAfterCurrentJob(.abandonWaylandSources)

        #expect(executor.lifecycleSnapshotForTesting.state == .joined(.orderly))
    }

    @Test
    func startingStateReturnsNotReadyRejection() {
        let state = WaylandThreadExecutorState()

        #expect(state.rejectionError() == .executorNotReady)
    }

    @Test
    func requestStopAfterLoopExitDoesNotRewriteShutdownMode() {
        var state = WaylandThreadExecutorState()
        state.phase = .loopExited(.orderly)

        _ = state.requestStop(.abandonWaylandSources)

        #expect(state.phase == .loopExited(.orderly))
    }

    @Test
    func markLoopExitedDuringJoiningPreservesJoiningState() {
        var state = WaylandThreadExecutorState()
        state.phase = .joining(.abandonWaylandSources, loopExited: false)

        state.markLoopExited()

        #expect(state.phase == .joining(.abandonWaylandSources, loopExited: true))
    }

    @Test
    func requestStopAfterJoinLoopExitDoesNotRewriteShutdownMode() {
        var state = WaylandThreadExecutorState()
        state.phase = .joining(.orderly, loopExited: true)

        _ = state.requestStop(.abandonWaylandSources)

        #expect(state.phase == .joining(.orderly, loopExited: true))
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

        try executor.syncBootstrapOnly {
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

        try executor.syncBootstrapOnly {
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
