// swiftlint:disable file_length
import CWaylandRuntimeShims
import Glibc

@safe
package final class WaylandThreadExecutor: SerialExecutor {
    private static let jobBudget = 64

    // SAFETY: The executor owns these pthread-backed fields for its lifetime.
    // `state` is read or mutated while `mutex` is held, except for owner-thread
    // checks that compare against the already-started thread identity. The wake
    // fd and primitive liveness flag are initialized before the owner thread is
    // visible and are torn down only after shutdown joins the owner thread.
    nonisolated(unsafe) private var mutex = unsafe pthread_mutex_t()
    nonisolated(unsafe) private var condition = pthread_cond_t()
    nonisolated(unsafe) private var readyCondition = pthread_cond_t()
    nonisolated(unsafe) private var wakeFileDescriptorStorage: CInt = -1
    nonisolated(unsafe) private var synchronizationPrimitivesAreLive = false
    nonisolated(unsafe) private var state = WaylandThreadExecutorState()

    package init(name _: String = "wayland-client-kit") throws {
        try initialize(forcedThreadCreationFailureForTesting: nil)
    }

    package init(
        forcingThreadCreationFailureForTesting errorCode: Int32,
        wakeFileDescriptorForTesting testingWakeFileDescriptor: CInt? = nil,
        closeWakeFileDescriptorForTesting testingCloseWakeFileDescriptor:
            (@Sendable (CInt) -> CInt)? = nil
    ) throws {
        try initialize(
            forcedThreadCreationFailureForTesting: errorCode,
            wakeFileDescriptorForTesting: testingWakeFileDescriptor,
            closeWakeFileDescriptorForTesting: testingCloseWakeFileDescriptor
        )
    }

    private func initialize(
        forcedThreadCreationFailureForTesting forcedThreadCreationFailure: Int32?,
        wakeFileDescriptorForTesting testingWakeFileDescriptor: CInt? = nil,
        closeWakeFileDescriptorForTesting testingCloseWakeFileDescriptor:
            (@Sendable (CInt) -> CInt)? = nil
    ) throws {
        if let failure = initializeSynchronizationPrimitives() {
            throw WaylandThreadExecutorError.executorFailedToStart(failure)
        }

        let wakeFileDescriptor: CInt
        if let testingWakeFileDescriptor {
            wakeFileDescriptor = testingWakeFileDescriptor
        } else {
            wakeFileDescriptor = unsafe swl_eventfd(
                0,
                swl_efd_cloexec() | swl_efd_nonblock()
            )
        }
        guard wakeFileDescriptor >= 0 else {
            let failure = ExecutorStartFailure.eventFileDescriptorCreationFailed(errno)
            markFailedToStart(failure)
            destroySynchronizationPrimitives()
            throw WaylandThreadExecutorError.executorFailedToStart(failure)
        }
        unsafe wakeFileDescriptorStorage = wakeFileDescriptor

        let retainedSelf = unsafe Unmanaged.passRetained(self).toOpaque()
        var createdThread = pthread_t()
        let createResult: Int32
        if let forcedThreadCreationFailure {
            createResult = forcedThreadCreationFailure
        } else {
            createResult = unsafe pthread_create(
                &createdThread,
                nil,
                { pointer in
                    guard let pointer = unsafe pointer else { return nil }

                    let executor = unsafe Unmanaged<WaylandThreadExecutor>
                        .fromOpaque(pointer)
                        .takeRetainedValue()
                    executor.runThread()
                    return nil
                },
                retainedSelf
            )
        }

        guard createResult == 0 else {
            let failure = ExecutorStartFailure.threadCreationFailed(createResult)
            markFailedToStart(failure)
            closeWakeFileDescriptor(using: testingCloseWakeFileDescriptor)
            destroySynchronizationPrimitives()
            unsafe Unmanaged<WaylandThreadExecutor>.fromOpaque(retainedSelf).release()
            throw WaylandThreadExecutorError.executorFailedToStart(failure)
        }

        unsafe pthread_mutex_lock(&mutex)
        unsafe state.thread = createdThread
        unsafe pthread_mutex_unlock(&mutex)

        waitUntilReady()
    }

    deinit {
        guard unsafe synchronizationPrimitivesAreLive else { return }

        if isOwnerThread {
            precondition(
                loopHasExited,
                "WaylandThreadExecutor owner thread released before loop exit"
            )
            detachOwnerThreadAfterLoopExit()
        } else {
            shutdown()
        }
        closeWakeFileDescriptor()
        destroySynchronizationPrimitives()
    }

    package func enqueue(_ job: consuming ExecutorJob) {
        guard case .accepted = enqueue(.job(ExecutorJobCell(job))) else {
            preconditionFailure(
                "WaylandThreadExecutor received a Swift executor job after executor teardown"
            )
        }
    }

    package func checkIsolated() {
        precondition(
            isOwnerThread,
            "WaylandThreadExecutor used from a different thread"
        )
    }

    // swiftlint:disable:next discouraged_optional_boolean
    package func isIsolatingCurrentContext() -> Bool? {
        isOwnerThread
    }

    package var isOwnerThread: Bool {
        unsafe pthread_mutex_lock(&mutex)
        let ownerThread = unsafe state.ownerThread
        unsafe pthread_mutex_unlock(&mutex)

        guard let ownerThread else { return false }
        return pthread_equal(ownerThread, pthread_self()) != 0
    }

    package var wakeFileDescriptor: CInt {
        unsafe wakeFileDescriptorStorage
    }

    package func installEventSource(_ source: any WaylandThreadEventSource)
        throws(WaylandThreadExecutorError)
    {
        unsafe pthread_mutex_lock(&mutex)
        guard unsafe state.phase.canAcceptWork else {
            let error = unsafe state.rejectionError()
            unsafe pthread_mutex_unlock(&mutex)
            throw error
        }

        unsafe state.eventSource = source
        unsafe pthread_cond_signal(&condition)
        signalWakeFileDescriptor()
        unsafe pthread_mutex_unlock(&mutex)
    }

    package func clearEventSource(_ source: (any WaylandThreadEventSource)? = nil) {
        unsafe pthread_mutex_lock(&mutex)
        let currentEventSource = unsafe state.eventSource
        if source == nil || currentEventSource === source {
            unsafe state.eventSource = nil
        }
        unsafe pthread_cond_signal(&condition)
        signalWakeFileDescriptor()
        unsafe pthread_mutex_unlock(&mutex)
    }

    package func abandonWaylandEventSourceWithoutDestroyingRawResources() {
        unsafe pthread_mutex_lock(&mutex)
        unsafe state.eventSource = nil
        unsafe pthread_cond_signal(&condition)
        signalWakeFileDescriptor()
        unsafe pthread_mutex_unlock(&mutex)
    }

    package func drainWakeFileDescriptor() {
        do {
            try Self.drainWakeFileDescriptor(unsafe wakeFileDescriptorStorage)
        } catch {
            preconditionFailure(String(describing: error))
        }
    }

    @available(*, noasync, message: "Only for executor bootstrap and tests.")
    package func syncBootstrapOnly<ResultValue: Sendable>(
        _ operation: @Sendable @escaping () throws(WaylandThreadExecutorError) -> ResultValue
    ) throws(WaylandThreadExecutorError) -> ResultValue {
        if isOwnerThread {
            return try operation()
        }

        let synchronousOperation = try SynchronousOperation(operation)
        switch enqueue(
            .operation {
                synchronousOperation.run()
            }
        ) {
        case .accepted:
            break
        case .rejected(let error):
            throw error
        }

        return try synchronousOperation.wait()
    }

    #if ENABLE_TESTING
        package func enqueueOperationForTesting(
            _ operation: @Sendable @escaping () -> Void
        ) throws {
            switch enqueue(.operation(operation)) {
            case .accepted:
                break
            case .rejected(let error):
                throw error
            }
        }

        package var lifecycleSnapshotForTesting: ExecutorLifecycleSnapshot {
            unsafe pthread_mutex_lock(&mutex)
            let snapshotState = unsafe state
            let phase = snapshotState.phase
            let queuedJobCount = snapshotState.workItems.count { workItem in
                if case .job = workItem { return true }
                return false
            }
            let queuedOperationCount = snapshotState.workItems.count { workItem in
                if case .operation = workItem { return true }
                return false
            }
            let snapshot = ExecutorLifecycleSnapshot(
                state: phase,
                isOwnerThread: snapshotState.ownerThread.map { ownerThread in
                    pthread_equal(ownerThread, pthread_self()) != 0
                } ?? false,
                hasThreadStarted: snapshotState.hasThreadStarted,
                loopHasExited: phase.loopHasExited,
                hasJoinedThread: phase.hasJoinedThread,
                queuedJobCount: queuedJobCount,
                queuedOperationCount: queuedOperationCount,
                acceptedJobCount: snapshotState.acceptedJobCount,
                completedJobCount: snapshotState.completedJobCount,
                acceptedOperationCount: snapshotState.acceptedOperationCount,
                completedOperationCount: snapshotState.completedOperationCount
            )
            unsafe pthread_mutex_unlock(&mutex)
            return snapshot
        }
    #endif

    package func requestStopAfterCurrentJob(_ mode: ShutdownMode = .orderly) {
        unsafe pthread_mutex_lock(&mutex)
        if mode == .abandonWaylandSources {
            unsafe state.eventSource = nil
        }

        if unsafe state.requestStop(mode) {
            unsafe state.workItems.append(.stop)
        }

        unsafe pthread_cond_signal(&condition)
        signalWakeFileDescriptor()
        unsafe pthread_mutex_unlock(&mutex)
    }

    package func shutdown(_ mode: ShutdownMode = .orderly) {
        requestStopAfterCurrentJob(mode)

        let shouldJoin = !isOwnerThread
        if shouldJoin {
            joinThread()
        }
    }
}

extension WaylandThreadExecutor {
    private func initializeSynchronizationPrimitives() -> ExecutorStartFailure? {
        let mutexResult = unsafe pthread_mutex_init(&mutex, nil)
        guard mutexResult == 0 else {
            return .syncPrimitiveInitFailed(
                function: "pthread_mutex_init",
                code: mutexResult
            )
        }

        let conditionResult = unsafe pthread_cond_init(&condition, nil)
        guard conditionResult == 0 else {
            unsafe pthread_mutex_destroy(&mutex)
            return .syncPrimitiveInitFailed(
                function: "pthread_cond_init(condition)",
                code: conditionResult
            )
        }

        let readyConditionResult = unsafe pthread_cond_init(&readyCondition, nil)
        guard readyConditionResult == 0 else {
            unsafe pthread_cond_destroy(&condition)
            unsafe pthread_mutex_destroy(&mutex)
            return .syncPrimitiveInitFailed(
                function: "pthread_cond_init(readyCondition)",
                code: readyConditionResult
            )
        }

        unsafe synchronizationPrimitivesAreLive = true
        return nil
    }

    private func enqueue(
        _ workItem: WaylandThreadExecutorWorkItem
    ) -> WaylandThreadExecutorEnqueueResult {
        unsafe pthread_mutex_lock(&mutex)
        guard unsafe state.phase.canAcceptWork else {
            let error = unsafe state.rejectionError()
            unsafe pthread_mutex_unlock(&mutex)
            return .rejected(error)
        }

        switch workItem {
        case .job:
            unsafe state.acceptedJobCount += 1
        case .operation:
            unsafe state.acceptedOperationCount += 1
        case .stop:
            break
        }
        unsafe state.workItems.append(workItem)
        unsafe pthread_cond_signal(&condition)
        signalWakeFileDescriptor()
        unsafe pthread_mutex_unlock(&mutex)
        return .accepted
    }

    private func signalWakeFileDescriptor() {
        do {
            _ = try Self.signalWakeFileDescriptor(unsafe wakeFileDescriptorStorage)
        } catch {
            preconditionFailure(String(describing: error))
        }
    }

    private func waitUntilReady() {
        unsafe pthread_mutex_lock(&mutex)
        while unsafe state.phase == .starting {
            unsafe pthread_cond_wait(&readyCondition, &mutex)
        }
        unsafe pthread_mutex_unlock(&mutex)
    }

    private func runThread() {
        unsafe pthread_mutex_lock(&mutex)
        unsafe state.ownerThread = pthread_self()
        unsafe state.phase = .running
        unsafe pthread_cond_broadcast(&readyCondition)
        unsafe pthread_mutex_unlock(&mutex)

        defer {
            markLoopExited()
        }

        while true {
            drainWakeFileDescriptor()

            switch drainSwiftJobs() {
            case .continue:
                break
            case .stop:
                return
            }

            guard let source = currentEventSource() else {
                waitForWorkOrEventSource()
                continue
            }

            if source.isClosed {
                clearEventSource(source)
                continue
            }

            do {
                try runEventSourceTurn(
                    source,
                    timeoutMilliseconds: hasPendingWork ? 0 : -1,
                )
            } catch {
                source.handleEventLoopError(error)
                clearEventSource(source)
            }
        }
    }

    private enum JobDrainResult {
        case `continue`
        case stop
    }

    private func drainSwiftJobs() -> JobDrainResult {
        let maximumJobCount = isStoppingSnapshot ? Int.max : Self.jobBudget
        var drainedJobCount = 0
        var completedJobCount = 0
        var completedOperationCount = 0
        defer {
            recordCompleted(
                jobCount: completedJobCount,
                operationCount: completedOperationCount
            )
        }

        while drainedJobCount < maximumJobCount {
            guard let workItem = nextWorkItemIfPresent() else {
                return .continue
            }

            switch workItem {
            case .job(let cell):
                drainedJobCount += 1
                unsafe cell.run(on: asUnownedSerialExecutor())
                completedJobCount += 1
            case .operation(let operation):
                drainedJobCount += 1
                operation()
                completedOperationCount += 1
            case .stop:
                return .stop
            }
        }

        return .continue
    }

    private func nextWorkItemIfPresent() -> WaylandThreadExecutorWorkItem? {
        unsafe pthread_mutex_lock(&mutex)
        let workItem = unsafe state.workItems.popFirst()
        unsafe pthread_mutex_unlock(&mutex)
        return workItem
    }

    private func recordCompleted(jobCount: Int, operationCount: Int) {
        guard jobCount > 0 || operationCount > 0 else { return }

        unsafe pthread_mutex_lock(&mutex)
        unsafe state.completedJobCount += UInt64(jobCount)
        unsafe state.completedOperationCount += UInt64(operationCount)
        unsafe pthread_mutex_unlock(&mutex)
    }

    private var hasPendingWork: Bool {
        unsafe pthread_mutex_lock(&mutex)
        let hasPendingWork = unsafe !state.workItems.isEmpty
        unsafe pthread_mutex_unlock(&mutex)
        return hasPendingWork
    }

    private var isStoppingSnapshot: Bool {
        unsafe pthread_mutex_lock(&mutex)
        let stopping = unsafe state.phase.isStopping
        unsafe pthread_mutex_unlock(&mutex)
        return stopping
    }

    private func currentEventSource() -> (any WaylandThreadEventSource)? {
        unsafe pthread_mutex_lock(&mutex)
        let source = unsafe state.eventSource
        unsafe pthread_mutex_unlock(&mutex)
        return source
    }

    private func waitForWorkOrEventSource() {
        unsafe pthread_mutex_lock(&mutex)
        while unsafe state.workItems.isEmpty,
            unsafe state.eventSource == nil,
            unsafe !state.phase.isStopping
        {
            unsafe pthread_cond_wait(&condition, &mutex)
        }
        unsafe pthread_mutex_unlock(&mutex)
    }

    private func joinThread() {
        unsafe pthread_mutex_lock(&mutex)
        while true {
            if case .joining = unsafe state.phase {
                unsafe pthread_cond_wait(&condition, &mutex)
                continue
            }
            break
        }

        let hasJoinedThread = unsafe state.phase.hasJoinedThread
        guard !hasJoinedThread else {
            unsafe pthread_mutex_unlock(&mutex)
            return
        }

        guard let threadToJoin = unsafe state.thread else {
            unsafe pthread_mutex_unlock(&mutex)
            return
        }

        let mode = unsafe state.phase.shutdownMode ?? .orderly
        unsafe state.phase = .joining(mode)
        unsafe pthread_mutex_unlock(&mutex)

        pthread_join(threadToJoin, nil)
        markJoined()
    }

    private func detachOwnerThreadAfterLoopExit() {
        unsafe pthread_mutex_lock(&mutex)
        let phase = unsafe state.phase
        precondition(
            phase.loopHasExited,
            "WaylandThreadExecutor owner thread detached before loop exit"
        )
        guard let threadToDetach = unsafe state.thread else {
            unsafe pthread_mutex_unlock(&mutex)
            return
        }
        let mode = phase.shutdownMode ?? .orderly
        unsafe pthread_mutex_unlock(&mutex)

        let detachResult = pthread_detach(threadToDetach)
        precondition(
            detachResult == 0,
            "pthread_detach returned \(detachResult)"
        )

        unsafe pthread_mutex_lock(&mutex)
        unsafe state.thread = nil
        unsafe state.phase = .detachedAfterOwnerThreadExit(mode)
        unsafe pthread_cond_broadcast(&condition)
        unsafe pthread_cond_broadcast(&readyCondition)
        unsafe pthread_mutex_unlock(&mutex)
    }

    private func closeWakeFileDescriptor(
        using closeWakeFileDescriptor: (@Sendable (CInt) -> CInt)? = nil
    ) {
        let descriptor = unsafe wakeFileDescriptorStorage
        if descriptor >= 0 {
            if let closeWakeFileDescriptor {
                _ = closeWakeFileDescriptor(descriptor)
            } else {
                _ = close(descriptor)
            }
            unsafe wakeFileDescriptorStorage = -1
        }
    }

    private func destroySynchronizationPrimitives() {
        guard unsafe synchronizationPrimitivesAreLive else { return }

        unsafe pthread_mutex_lock(&mutex)
        let phase = unsafe state.phase
        precondition(
            phase.canDestroySynchronizationPrimitives,
            "WaylandThreadExecutor destroyed synchronization primitives before loop exit"
        )
        unsafe state.phase = .destroying
        unsafe pthread_mutex_unlock(&mutex)

        unsafe pthread_mutex_destroy(&mutex)
        unsafe pthread_cond_destroy(&condition)
        unsafe pthread_cond_destroy(&readyCondition)
        unsafe synchronizationPrimitivesAreLive = false
    }

    private var loopHasExited: Bool {
        unsafe pthread_mutex_lock(&mutex)
        let hasExited = unsafe state.phase.loopHasExited
        unsafe pthread_mutex_unlock(&mutex)
        return hasExited
    }

    private func markFailedToStart(_ failure: ExecutorStartFailure) {
        unsafe pthread_mutex_lock(&mutex)
        unsafe state.phase = .failedToStart(failure)
        unsafe pthread_cond_broadcast(&condition)
        unsafe pthread_cond_broadcast(&readyCondition)
        unsafe pthread_mutex_unlock(&mutex)
    }

    private func markLoopExited() {
        unsafe pthread_mutex_lock(&mutex)
        unsafe state.markLoopExited()
        unsafe pthread_cond_broadcast(&condition)
        unsafe pthread_cond_broadcast(&readyCondition)
        unsafe pthread_mutex_unlock(&mutex)
    }

    private func markJoined() {
        unsafe pthread_mutex_lock(&mutex)
        let mode = unsafe state.phase.shutdownMode ?? .orderly
        if unsafe state.phase != .destroying {
            unsafe state.phase = .joined(mode)
        }
        unsafe pthread_cond_broadcast(&condition)
        unsafe pthread_cond_broadcast(&readyCondition)
        unsafe pthread_mutex_unlock(&mutex)
    }
}
