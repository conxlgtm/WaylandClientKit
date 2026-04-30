import CWaylandUnsafeShim
import Glibc

package protocol WaylandThreadEventSource: AnyObject {
    var isClosed: Bool { get }

    func fileDescriptor() throws -> CInt
    func dispatchPending() throws -> Int32
    func prepareRead() throws -> Bool
    func flush() throws -> Bool
    func readEvents() throws
    func cancelRead()

    func handleEventLoopError(_ error: any Error)
}

public enum WaylandThreadExecutorError: Error, Equatable, Sendable, CustomStringConvertible {
    case eventFileDescriptorCreationFailed(Int32)
    case threadCreationFailed(Int32)
    case executorClosed
    case wakeFileDescriptorReadFailed(Int32)
    case wakeFileDescriptorShortRead(Int)
    case wakeFileDescriptorWriteFailed(Int32)
    case wakeFileDescriptorShortWrite(Int)
    case pollFailed(Int32)
    case pollEventFailed(revents: Int16)

    public var description: String {
        switch self {
        case .eventFileDescriptorCreationFailed(let errorCode):
            "failed to create Wayland owner thread wake fd: eventfd failed with errno \(errorCode)"
        case .threadCreationFailed(let code):
            "failed to create Wayland owner thread: pthread_create returned \(code)"
        case .executorClosed:
            "Wayland owner thread executor is closed"
        case .wakeFileDescriptorReadFailed(let errorCode):
            "Wayland owner thread wake fd read failed with errno \(errorCode)"
        case .wakeFileDescriptorShortRead(let byteCount):
            "Wayland owner thread wake fd read returned \(byteCount) bytes"
        case .wakeFileDescriptorWriteFailed(let errorCode):
            "Wayland owner thread wake fd write failed with errno \(errorCode)"
        case .wakeFileDescriptorShortWrite(let byteCount):
            "Wayland owner thread wake fd write returned \(byteCount) bytes"
        case .pollFailed(let errorCode):
            "Wayland owner thread poll failed with errno \(errorCode)"
        case .pollEventFailed(let revents):
            "Wayland owner thread poll returned error events \(revents)"
        }
    }
}

@safe
public final class WaylandThreadExecutor: SerialExecutor {
    private static let jobBudget = 64
    package static let pollFailureEvents = Int16(POLLERR) | Int16(POLLHUP) | Int16(POLLNVAL)

    private enum WorkItem {
        case job(ExecutorJobCell)
        case operation(@Sendable () -> Void)
        case stop
    }

    private nonisolated(unsafe) var mutex = unsafe pthread_mutex_t()
    private nonisolated(unsafe) var condition = pthread_cond_t()
    private nonisolated(unsafe) var readyCondition = pthread_cond_t()
    private nonisolated(unsafe) var thread = pthread_t()
    private nonisolated(unsafe) var ownerThread = pthread_t()
    private nonisolated(unsafe) var wakeFileDescriptorStorage: CInt = -1
    private nonisolated(unsafe) var isReady = false
    private nonisolated(unsafe) var isStopping = false
    private nonisolated(unsafe) var didJoin = false
    private nonisolated(unsafe) var didDestroySynchronizationPrimitives = false
    private nonisolated(unsafe) var workItems: [WorkItem] = []
    private nonisolated(unsafe) var eventSource: (any WaylandThreadEventSource)?

    public init(name _: String = "swift-wayland") throws {
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
        unsafe pthread_mutex_init(&mutex, nil)
        unsafe pthread_cond_init(&condition, nil)
        unsafe pthread_cond_init(&readyCondition, nil)

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
            destroySynchronizationPrimitives()
            throw WaylandThreadExecutorError.eventFileDescriptorCreationFailed(errno)
        }
        wakeFileDescriptorStorage = wakeFileDescriptor

        let retainedSelf = unsafe Unmanaged.passRetained(self).toOpaque()
        let createResult: Int32
        if let forcedThreadCreationFailure {
            createResult = forcedThreadCreationFailure
        } else {
            createResult = unsafe pthread_create(
                &thread,
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
            isStopping = true
            didJoin = true
            closeWakeFileDescriptor(using: testingCloseWakeFileDescriptor)
            destroySynchronizationPrimitives()
            unsafe Unmanaged<WaylandThreadExecutor>.fromOpaque(retainedSelf).release()
            throw WaylandThreadExecutorError.threadCreationFailed(createResult)
        }

        waitUntilReady()
    }

    deinit {
        guard !didDestroySynchronizationPrimitives else { return }

        shutdown()
        closeWakeFileDescriptor()
        destroySynchronizationPrimitives()
    }

    public func enqueue(_ job: consuming ExecutorJob) {
        guard enqueue(.job(ExecutorJobCell(job))) else {
            preconditionFailure("WaylandThreadExecutor dropped a job after shutdown")
        }
    }

    public func checkIsolated() {
        precondition(
            isOwnerThread,
            "WaylandThreadExecutor used from a different thread"
        )
    }

    // swiftlint:disable:next discouraged_optional_boolean
    public func isIsolatingCurrentContext() -> Bool? {
        isOwnerThread
    }

    public var isOwnerThread: Bool {
        unsafe pthread_equal(ownerThread, pthread_self()) != 0
    }

    package var wakeFileDescriptor: CInt {
        wakeFileDescriptorStorage
    }

    package func installEventSource(_ source: any WaylandThreadEventSource) throws {
        unsafe pthread_mutex_lock(&mutex)
        guard !isStopping else {
            unsafe pthread_mutex_unlock(&mutex)
            throw WaylandThreadExecutorError.executorClosed
        }

        eventSource = source
        unsafe pthread_cond_signal(&condition)
        signalWakeFileDescriptor()
        unsafe pthread_mutex_unlock(&mutex)
    }

    package func clearEventSource(_ source: (any WaylandThreadEventSource)? = nil) {
        unsafe pthread_mutex_lock(&mutex)
        if source == nil || eventSource === source {
            eventSource = nil
        }
        unsafe pthread_cond_signal(&condition)
        signalWakeFileDescriptor()
        unsafe pthread_mutex_unlock(&mutex)
    }

    package func abandonWaylandEventSourceWithoutDestroyingRawResources() {
        unsafe pthread_mutex_lock(&mutex)
        eventSource = nil
        unsafe pthread_cond_signal(&condition)
        signalWakeFileDescriptor()
        unsafe pthread_mutex_unlock(&mutex)
    }

    package func drainWakeFileDescriptor() {
        do {
            try Self.drainWakeFileDescriptor(wakeFileDescriptorStorage)
        } catch {
            preconditionFailure(String(describing: error))
        }
    }

    @available(*, noasync, message: "Use async actor methods on WaylandDisplay instead.")
    package func sync<ResultValue: Sendable>(
        _ operation: @Sendable @escaping () throws -> ResultValue
    ) throws -> ResultValue {
        if isOwnerThread {
            return try operation()
        }

        let synchronousOperation = SynchronousOperation(operation)
        guard
            enqueue(
                .operation {
                    synchronousOperation.run()
                }
            )
        else {
            throw WaylandThreadExecutorError.executorClosed
        }

        return try synchronousOperation.wait()
    }

    package func requestStopAfterCurrentJob(abandoningWaylandSources: Bool = false) {
        unsafe pthread_mutex_lock(&mutex)
        if abandoningWaylandSources {
            eventSource = nil
        }

        guard !isStopping else {
            unsafe pthread_mutex_unlock(&mutex)
            return
        }

        isStopping = true
        workItems.append(.stop)
        unsafe pthread_cond_signal(&condition)
        signalWakeFileDescriptor()
        unsafe pthread_mutex_unlock(&mutex)
    }

    public func shutdown(abandoningWaylandSources: Bool = false) {
        requestStopAfterCurrentJob(abandoningWaylandSources: abandoningWaylandSources)

        let shouldJoin = !isOwnerThread
        if shouldJoin {
            joinThread()
        }
    }
}

extension WaylandThreadExecutor {
    private func enqueue(_ workItem: WorkItem) -> Bool {
        unsafe pthread_mutex_lock(&mutex)
        guard !isStopping else {
            unsafe pthread_mutex_unlock(&mutex)
            return false
        }

        workItems.append(workItem)
        unsafe pthread_cond_signal(&condition)
        signalWakeFileDescriptor()
        unsafe pthread_mutex_unlock(&mutex)
        return true
    }

    private func signalWakeFileDescriptor() {
        do {
            _ = try Self.signalWakeFileDescriptor(wakeFileDescriptorStorage)
        } catch {
            preconditionFailure(String(describing: error))
        }
    }

    private func waitUntilReady() {
        unsafe pthread_mutex_lock(&mutex)
        while !isReady {
            unsafe pthread_cond_wait(&readyCondition, &mutex)
        }
        unsafe pthread_mutex_unlock(&mutex)
    }

    private func runThread() {
        unsafe pthread_mutex_lock(&mutex)
        unsafe ownerThread = pthread_self()
        isReady = true
        unsafe pthread_cond_broadcast(&readyCondition)
        unsafe pthread_mutex_unlock(&mutex)

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

        while drainedJobCount < maximumJobCount {
            guard let workItem = nextWorkItemIfPresent() else {
                return .continue
            }

            switch workItem {
            case .job(let cell):
                drainedJobCount += 1
                cell.run(on: asUnownedSerialExecutor())
            case .operation(let operation):
                drainedJobCount += 1
                operation()
            case .stop:
                return .stop
            }
        }

        return .continue
    }

    private func nextWorkItemIfPresent() -> WorkItem? {
        unsafe pthread_mutex_lock(&mutex)
        let workItem = workItems.isEmpty ? nil : workItems.removeFirst()
        unsafe pthread_mutex_unlock(&mutex)
        return workItem
    }

    private var hasPendingWork: Bool {
        unsafe pthread_mutex_lock(&mutex)
        let hasPendingWork = !workItems.isEmpty
        unsafe pthread_mutex_unlock(&mutex)
        return hasPendingWork
    }

    private var isStoppingSnapshot: Bool {
        unsafe pthread_mutex_lock(&mutex)
        let stopping = isStopping
        unsafe pthread_mutex_unlock(&mutex)
        return stopping
    }

    private func currentEventSource() -> (any WaylandThreadEventSource)? {
        unsafe pthread_mutex_lock(&mutex)
        let source = eventSource
        unsafe pthread_mutex_unlock(&mutex)
        return source
    }

    private func waitForWorkOrEventSource() {
        unsafe pthread_mutex_lock(&mutex)
        while workItems.isEmpty,
            eventSource == nil,
            !isStopping
        {
            unsafe pthread_cond_wait(&condition, &mutex)
        }
        unsafe pthread_mutex_unlock(&mutex)
    }

    private func joinThread() {
        unsafe pthread_mutex_lock(&mutex)
        guard !didJoin else {
            unsafe pthread_mutex_unlock(&mutex)
            return
        }
        didJoin = true
        let threadToJoin = thread
        unsafe pthread_mutex_unlock(&mutex)

        pthread_join(threadToJoin, nil)
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
        guard !didDestroySynchronizationPrimitives else { return }

        unsafe pthread_mutex_destroy(&mutex)
        unsafe pthread_cond_destroy(&condition)
        unsafe pthread_cond_destroy(&readyCondition)
        didDestroySynchronizationPrimitives = true
    }
}
