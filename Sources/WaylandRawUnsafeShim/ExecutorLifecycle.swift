public enum ShutdownMode: Equatable, Sendable {
    case orderly
    case abandonWaylandSources

    package func merged(with requestedMode: ShutdownMode) -> ShutdownMode {
        switch (self, requestedMode) {
        case (.abandonWaylandSources, _), (_, .abandonWaylandSources):
            .abandonWaylandSources
        case (.orderly, .orderly):
            .orderly
        }
    }
}

public enum ExecutorStartFailure: Equatable, Sendable {
    case eventFileDescriptorCreationFailed(Int32)
    case threadCreationFailed(Int32)
}

package enum ExecutorLifecycle: Equatable, Sendable {
    case starting
    case running
    case stopRequested(ShutdownMode)
    case loopExited(ShutdownMode)
    case joining(ShutdownMode, loopExited: Bool)
    case joined(ShutdownMode)
    case failedToStart(ExecutorStartFailure)
    case destroying

    package var isStopping: Bool {
        switch self {
        case .stopRequested, .loopExited, .joining, .joined, .destroying:
            true
        case .starting, .running, .failedToStart:
            false
        }
    }

    package var canAcceptWork: Bool {
        self == .running
    }

    package var loopHasExited: Bool {
        switch self {
        case .loopExited, .joined, .destroying:
            true
        case .joining(_, let loopExited):
            loopExited
        case .starting, .running, .stopRequested, .failedToStart:
            false
        }
    }

    package var hasJoinedThread: Bool {
        switch self {
        case .joined, .destroying:
            true
        case .starting, .running, .stopRequested, .loopExited, .joining, .failedToStart:
            false
        }
    }

    package var canDestroySynchronizationPrimitives: Bool {
        switch self {
        case .loopExited, .joined, .failedToStart:
            true
        case .starting, .running, .stopRequested, .joining, .destroying:
            false
        }
    }

    package var shutdownMode: ShutdownMode? {
        switch self {
        case .stopRequested(let mode),
            .loopExited(let mode),
            .joining(let mode, _),
            .joined(let mode):
            mode
        case .starting, .running, .failedToStart, .destroying:
            nil
        }
    }
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
        package var acceptedJobCount: UInt64
        package var completedJobCount: UInt64
        package var acceptedOperationCount: UInt64
        package var completedOperationCount: UInt64
    }
#endif
