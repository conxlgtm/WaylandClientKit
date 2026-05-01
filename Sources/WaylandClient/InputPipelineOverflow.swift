public enum InputPipelineOverflowStage: Equatable, Sendable {
    case rawInputQueue
    case sessionPendingInput
}

extension InputPipelineOverflowStage: CustomStringConvertible {
    public var description: String {
        switch self {
        case .rawInputQueue:
            "raw input queue"
        case .sessionPendingInput:
            "session pending input queue"
        }
    }
}

public struct InputPipelineOverflow: Equatable, Sendable {
    public let stage: InputPipelineOverflowStage
    public let capacity: Int

    public init(stage overflowStage: InputPipelineOverflowStage, capacity queueCapacity: Int) {
        stage = overflowStage
        capacity = queueCapacity
    }
}
