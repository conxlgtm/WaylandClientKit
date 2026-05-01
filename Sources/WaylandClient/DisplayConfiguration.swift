/// Overflow is scoped to the individual subscription whose buffer filled.
/// The display connection remains alive; create a new subscription to resume
/// receiving future events. Events discarded by overflow are not replayed.
public enum EventStreamOverflowPolicy: Equatable, Sendable {
    case failFast
}

public struct EventStreamConfiguration: Equatable, Sendable {
    public var displayEventCapacity: Int
    public var inputEventCapacity: Int
    public var overflowPolicy: EventStreamOverflowPolicy

    public init(
        displayEventCapacity displayCapacity: Int = 256,
        inputEventCapacity inputCapacity: Int = 1_024,
        overflowPolicy policy: EventStreamOverflowPolicy = .failFast
    ) {
        displayEventCapacity = displayCapacity
        inputEventCapacity = inputCapacity
        overflowPolicy = policy
    }

    package func validate() throws {
        guard displayEventCapacity > 0 else {
            throw ClientError.invalidDisplayState(
                "displayEventCapacity must be greater than zero"
            )
        }

        guard inputEventCapacity > 0 else {
            throw ClientError.invalidDisplayState(
                "inputEventCapacity must be greater than zero"
            )
        }
    }
}

public struct InputMotionCoalescing: OptionSet, Equatable, Sendable {
    public let rawValue: Int

    public init(rawValue coalescingRawValue: Int) {
        rawValue = coalescingRawValue
    }

    public static let pointerMotion = InputMotionCoalescing(rawValue: 1 << 0)
    public static let touchMotion = InputMotionCoalescing(rawValue: 1 << 1)
    public static let all: InputMotionCoalescing = [.pointerMotion, .touchMotion]
}

public struct InputPipelineConfiguration: Equatable, Sendable {
    public var rawInputQueueCapacity: Int
    public var pendingInputEventCapacity: Int
    public var motionCoalescing: InputMotionCoalescing

    public var pointerMotionCoalescing: Bool {
        get { motionCoalescing.contains(.pointerMotion) }
        set {
            if newValue {
                motionCoalescing.insert(.pointerMotion)
            } else {
                motionCoalescing.remove(.pointerMotion)
            }
        }
    }

    public var touchMotionCoalescing: Bool {
        get { motionCoalescing.contains(.touchMotion) }
        set {
            if newValue {
                motionCoalescing.insert(.touchMotion)
            } else {
                motionCoalescing.remove(.touchMotion)
            }
        }
    }

    public init(
        rawInputQueueCapacity rawCapacity: Int = 4_096,
        pendingInputEventCapacity pendingCapacity: Int = 2_048,
        pointerMotionCoalescing shouldCoalescePointerMotion: Bool = true,
        touchMotionCoalescing shouldCoalesceTouchMotion: Bool = true
    ) {
        rawInputQueueCapacity = rawCapacity
        pendingInputEventCapacity = pendingCapacity
        motionCoalescing = []
        pointerMotionCoalescing = shouldCoalescePointerMotion
        touchMotionCoalescing = shouldCoalesceTouchMotion
    }

    public init(
        motionCoalescing coalescingPolicy: InputMotionCoalescing,
        rawInputQueueCapacity rawCapacity: Int = 4_096,
        pendingInputEventCapacity pendingCapacity: Int = 2_048
    ) {
        rawInputQueueCapacity = rawCapacity
        pendingInputEventCapacity = pendingCapacity
        motionCoalescing = coalescingPolicy
    }

    package func validate() throws {
        guard rawInputQueueCapacity > 0 else {
            throw ClientError.invalidDisplayState(
                "rawInputQueueCapacity must be greater than zero"
            )
        }

        guard pendingInputEventCapacity > 0 else {
            throw ClientError.invalidDisplayState(
                "pendingInputEventCapacity must be greater than zero"
            )
        }
    }
}

public struct DiagnosticsConfiguration: Equatable, Sendable {
    public var capacity: Int

    public init(capacity diagnosticsCapacity: Int = 128) {
        capacity = diagnosticsCapacity
    }

    package func validate() throws {
        guard capacity > 0 else {
            throw ClientError.invalidDisplayState(
                "diagnostics capacity must be greater than zero"
            )
        }
    }
}

public struct DisplayConfiguration: Equatable, Sendable {
    public var eventStreams: EventStreamConfiguration
    public var inputPipeline: InputPipelineConfiguration
    public var diagnostics: DiagnosticsConfiguration

    public init(
        eventStreams streamConfiguration: EventStreamConfiguration = .init(),
        inputPipeline inputConfiguration: InputPipelineConfiguration = .init(),
        diagnostics diagnosticsConfiguration: DiagnosticsConfiguration = .init()
    ) {
        eventStreams = streamConfiguration
        inputPipeline = inputConfiguration
        diagnostics = diagnosticsConfiguration
    }

    package func validate() throws {
        try eventStreams.validate()
        try inputPipeline.validate()
        try diagnostics.validate()
    }
}
