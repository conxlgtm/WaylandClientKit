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
    public let capacity: InputPipelineCapacity

    public init(
        stage overflowStage: InputPipelineOverflowStage,
        capacity overflowCapacity: InputPipelineCapacity
    ) {
        stage = overflowStage
        capacity = overflowCapacity
    }

    public init(stage overflowStage: InputPipelineOverflowStage, capacity value: Int) throws {
        try self.init(stage: overflowStage, capacity: InputPipelineCapacity(value))
    }
}

public enum InputPipelineOverflowError: Error, Equatable, Sendable {
    case nonPositiveCapacity(Int)
}

public struct InputPipelineCapacity: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(_ value: Int) throws {
        guard value > 0 else {
            throw InputPipelineOverflowError.nonPositiveCapacity(value)
        }

        rawValue = value
    }

    package init(unchecked value: Int) {
        precondition(value > 0, "input pipeline capacity must be positive")
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
