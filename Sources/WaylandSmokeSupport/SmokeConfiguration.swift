package struct SmokeConfiguration: Equatable, Sendable {
    package var timeoutMilliseconds: Int32
    package var postCommitPumpMilliseconds: Int32

    package init(
        timeoutMilliseconds timeout: Int32 = 5_000,
        postCommitPumpMilliseconds postCommitPump: Int32 = 16
    ) {
        timeoutMilliseconds = timeout
        postCommitPumpMilliseconds = postCommitPump
    }
}

package enum SmokeCommand: Equatable, Sendable {
    case run(SmokeConfiguration)
    case help
}

package enum SmokeResult: Equatable, Sendable, CustomStringConvertible {
    case committedFrame
    case frameCallbackObserved

    package var description: String {
        switch self {
        case .committedFrame:
            "committed frame"
        case .frameCallbackObserved:
            "frame callback observed"
        }
    }
}
