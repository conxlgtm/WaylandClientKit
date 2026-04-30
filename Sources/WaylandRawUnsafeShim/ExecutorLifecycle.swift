package enum ExecutorLifecycle: Equatable, Sendable {
    case starting
    case running
    case stopRequested
    case loopExited
    case joined
    case destroyed
}

#if ENABLE_TESTING
    package struct ExecutorLifecycleSnapshot: Equatable, Sendable {
        package var state: ExecutorLifecycle
        package var isOwnerThread: Bool
        package var hasThreadStarted: Bool
        package var loopHasExited: Bool
        package var hasJoinedThread: Bool
        package var queuedJobCount: Int
        package var queuedOperationCount: Int
    }
#endif
