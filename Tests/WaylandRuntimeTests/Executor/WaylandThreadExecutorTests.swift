// swiftlint:disable file_length

#if ENABLE_TESTING
    import Foundation
    import Glibc
    import Synchronization
    import Testing

    @testable import WaylandRaw
    @testable import WaylandRuntime

    private actor ExecutorProbe {
        private let executor: WaylandThreadExecutor

        nonisolated var unownedExecutor: UnownedSerialExecutor {
            unsafe executor.asUnownedSerialExecutor()
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
        private let signalWriteDescriptor: CInt?
        private let state = Mutex(State())

        init(
            executor sourceExecutor: WaylandThreadExecutor,
            signalWriteDescriptor descriptor: CInt? = nil
        ) {
            executor = sourceExecutor
            signalWriteDescriptor = descriptor
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
            signalReadEvents()
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

        private func signalReadEvents() {
            guard let signalWriteDescriptor else {
                return
            }

            var byte = UInt8(1)
            _ = unsafe withUnsafeBytes(of: &byte) { buffer in
                unsafe Glibc.write(signalWriteDescriptor, buffer.baseAddress, 1)
            }
        }
    }

    private final class FailingReadEventSourceProbe: WaylandThreadEventSource, Sendable {
        private struct State: Sendable {
            var readEventsCallCount = 0
            var cancelReadCallCount = 0
            var eventLoopErrorCount = 0
        }

        private let executor: WaylandThreadExecutor
        private let signalWriteDescriptor: CInt?
        private let state = Mutex(State())

        init(
            executor sourceExecutor: WaylandThreadExecutor,
            signalWriteDescriptor descriptor: CInt? = nil
        ) {
            executor = sourceExecutor
            signalWriteDescriptor = descriptor
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
            throw RuntimeError.systemError(errno: EPIPE, operation: .displayReadEvents)
        }

        func cancelRead() {
            state.withLock { $0.cancelReadCallCount += 1 }
        }

        func handleEventLoopError(_: any Error) {
            state.withLock { $0.eventLoopErrorCount += 1 }
            signalReadEventFailure()
        }

        private func signalReadEventFailure() {
            guard let signalWriteDescriptor else {
                return
            }

            var byte = UInt8(1)
            _ = unsafe withUnsafeBytes(of: &byte) { buffer in
                unsafe Glibc.write(signalWriteDescriptor, buffer.baseAddress, 1)
            }
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

    // SAFETY: Gate state is private and every access is protected by NSCondition.
    private final class OwnerThreadGate: @unchecked Sendable {
        private struct State: Sendable {
            var didEnter = false
            var isOpen = false
        }

        private let condition = NSCondition()
        private var state = State()

        func enterAndWaitUntilOpened() {
            condition.lock()
            state.didEnter = true
            condition.broadcast()
            while !state.isOpen {
                condition.wait()
            }
            condition.unlock()
        }

        func waitUntilEntered() -> Bool {
            condition.lock()
            defer { condition.unlock() }
            guard !state.didEnter else {
                return true
            }

            let deadline = Date().addingTimeInterval(1)
            while !state.didEnter {
                guard condition.wait(until: deadline) else {
                    return false
                }
            }
            return true
        }

        func open() {
            condition.lock()
            state.isOpen = true
            condition.broadcast()
            condition.unlock()
        }
    }

    @Suite(.timeLimit(.minutes(1)))
    struct WaylandThreadExecutorTests {
        @Test
        func threadCreationFailureClosesWakeFileDescriptor() throws {
            let closedDescriptors = Mutex<[CInt]>([])
            let testingWakeFileDescriptor: CInt = 42

            #expect(
                throws: WaylandThreadExecutorError.executorFailedToStart(
                    .threadCreationFailed(EAGAIN)
                )
            ) {
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
        func syncBootstrapOnlyPropagatesSendableOperationFailure() throws {
            let executor = try WaylandThreadExecutor()
            defer { executor.shutdown() }

            do {
                try executor.syncBootstrapOnly(throwExecutorNotReady)
                Issue.record("operation unexpectedly succeeded")
            } catch {
                #expect(error == .executorNotReady)
            }
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
        func runningStateRejectionErrorExits() async {
            await #expect(processExitsWith: .failure) {
                var state = WaylandThreadExecutorState()
                state.phase = .running
                _ = state.rejectionError()
            }
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
            state.phase = .joining(.abandonWaylandSources)

            state.markLoopExited()

            #expect(state.phase == .joining(.abandonWaylandSources))
        }

        @Test
        func requestStopDuringJoiningDoesNotRewriteShutdownMode() {
            var state = WaylandThreadExecutorState()
            state.phase = .joining(.orderly)

            _ = state.requestStop(.abandonWaylandSources)

            #expect(state.phase == .joining(.orderly))
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
            let signalDescriptors = try makeExecutorTestPipeDescriptors()
            defer {
                closeExecutorTestDescriptor(signalDescriptors.readEnd)
                closeExecutorTestDescriptor(signalDescriptors.writeEnd)
            }
            let executor = try WaylandThreadExecutor()
            defer { executor.shutdown() }
            let source = EventSourceProbe(
                executor: executor,
                signalWriteDescriptor: signalDescriptors.writeEnd
            )
            let installSource: @Sendable () throws(WaylandThreadExecutorError) -> Void = {
                try executor.installEventSource(source)
            }

            try executor.syncBootstrapOnly(installSource)
            try waitForExecutorTestPipeSignal(signalDescriptors.readEnd)

            let snapshot = source.snapshot()
            #expect(snapshot.pollCount > 0)
            #expect(snapshot.didRunOnOwnerThread)
        }

        @Test
        func readEventFailureDoesNotCancelResolvedReadIntent() throws {
            let signalDescriptors = try makeExecutorTestPipeDescriptors()
            defer {
                closeExecutorTestDescriptor(signalDescriptors.readEnd)
                closeExecutorTestDescriptor(signalDescriptors.writeEnd)
            }
            let executor = try WaylandThreadExecutor()
            defer { executor.shutdown() }
            let source = FailingReadEventSourceProbe(
                executor: executor,
                signalWriteDescriptor: signalDescriptors.writeEnd
            )
            let installSource: @Sendable () throws(WaylandThreadExecutorError) -> Void = {
                try executor.installEventSource(source)
            }

            try executor.syncBootstrapOnly(installSource)
            try waitForExecutorTestPipeSignal(signalDescriptors.readEnd)
            executor.shutdown()

            let snapshot = source.snapshot()
            #expect(snapshot.eventLoopErrorCount == 1)
            #expect(snapshot.readEventsCallCount == 1)
            #expect(snapshot.cancelReadCallCount == 0)
        }
    }

    private func throwExecutorNotReady() throws(WaylandThreadExecutorError) {
        throw WaylandThreadExecutorError.executorNotReady
    }

#endif
