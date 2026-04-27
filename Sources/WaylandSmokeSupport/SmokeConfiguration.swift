public struct SmokeConfiguration: Equatable, Sendable {
    public var timeoutMilliseconds: Int32
    public var postCommitPumpMilliseconds: Int32

    public init(
        timeoutMilliseconds timeout: Int32 = 5_000,
        postCommitPumpMilliseconds postCommitPump: Int32 = 16
    ) {
        timeoutMilliseconds = timeout
        postCommitPumpMilliseconds = postCommitPump
    }
}

public enum SmokeCommand: Equatable, Sendable {
    case run(SmokeConfiguration)
    case help
}

public enum SmokeResult: Equatable, Sendable, CustomStringConvertible {
    case committedFrame
    case frameCallbackObserved

    public var description: String {
        switch self {
        case .committedFrame:
            "committed frame"
        case .frameCallbackObserved:
            "frame callback observed"
        }
    }
}
