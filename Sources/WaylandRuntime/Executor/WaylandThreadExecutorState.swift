import Glibc

enum WaylandThreadExecutorWorkItem {
    case job(ExecutorJobCell)
    case operation(@Sendable () -> Void)
    case stop
}

struct WaylandThreadExecutorState {
    var phase = ExecutorLifecycle.starting
    var ownerThread: pthread_t?
    var thread: pthread_t?
    var acceptedJobCount: UInt64 = 0
    var completedJobCount: UInt64 = 0
    var acceptedOperationCount: UInt64 = 0
    var completedOperationCount: UInt64 = 0
    var workItems = WaylandThreadWorkQueue<WaylandThreadExecutorWorkItem>()
    var eventSource: (any WaylandThreadEventSource)?

    var hasThreadStarted: Bool {
        ownerThread != nil
    }

    mutating func requestStop(_ mode: ShutdownMode) -> Bool {
        switch phase {
        case .starting, .running:
            phase = .stopRequested(mode)
            return true
        case .stopRequested(let existingMode):
            phase = .stopRequested(existingMode.merged(with: mode))
            return false
        case .joining:
            return false
        case .loopExited, .joined, .detachedAfterOwnerThreadExit:
            return false
        case .failedToStart, .destroying:
            return false
        }
    }

    mutating func markLoopExited() {
        switch phase {
        case .starting:
            preconditionFailure("WaylandThreadExecutor loop exited before thread started running")
        case .running:
            preconditionFailure("WaylandThreadExecutor loop exited without a stop request")
        case .stopRequested(let mode), .loopExited(let mode):
            phase = .loopExited(mode)
        case .joining:
            return
        case .joined, .detachedAfterOwnerThreadExit, .failedToStart, .destroying:
            return
        }
    }

    func rejectionError() -> WaylandThreadExecutorError {
        precondition(!phase.canAcceptWork, "rejectionError called while executor accepts work")

        return switch phase {
        case .running:
            preconditionFailure("rejectionError called while executor is running")
        case .stopRequested(let mode), .joining(let mode):
            .executorStopping(mode)
        case .loopExited, .joined, .detachedAfterOwnerThreadExit, .destroying:
            .executorStopped
        case .failedToStart(let failure):
            .executorFailedToStart(failure)
        case .starting:
            .executorNotReady
        }
    }
}

enum WaylandThreadExecutorEnqueueResult {
    case accepted
    case rejected(WaylandThreadExecutorError)
}
