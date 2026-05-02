/// Overflow is scoped to the individual subscription whose buffer filled.
/// The display connection remains alive; create a new subscription to resume
/// receiving future events. Events discarded by overflow are not replayed.
public enum EventStreamOverflowPolicy: Equatable, Sendable {
    case failFast
}

public struct EventStreamConfiguration: Equatable, Sendable {
    public var displayEventCapacity: EventStreamCapacity
    public var inputEventCapacity: EventStreamCapacity
    public var overflowPolicy: EventStreamOverflowPolicy

    public init(
        displayEventCapacity displayCapacity: EventStreamCapacity = .defaultDisplayEvents,
        inputEventCapacity inputCapacity: EventStreamCapacity = .defaultInputEvents,
        overflowPolicy policy: EventStreamOverflowPolicy = .failFast
    ) {
        displayEventCapacity = displayCapacity
        inputEventCapacity = inputCapacity
        overflowPolicy = policy
    }

    public init(
        displayEventCapacity displayCapacity: Int,
        inputEventCapacity inputCapacity: Int = EventStreamCapacity.defaultInputEvents.rawValue,
        overflowPolicy policy: EventStreamOverflowPolicy = .failFast
    ) throws {
        displayEventCapacity = try EventStreamCapacity(
            displayCapacity,
            field: .displayEventCapacity
        )
        inputEventCapacity = try EventStreamCapacity(
            inputCapacity,
            field: .inputEventCapacity
        )
        overflowPolicy = policy
    }

    public init(
        inputEventCapacity inputCapacity: Int,
        displayEventCapacity displayCapacity: Int =
            EventStreamCapacity.defaultDisplayEvents.rawValue,
        overflowPolicy policy: EventStreamOverflowPolicy = .failFast
    ) throws {
        displayEventCapacity = try EventStreamCapacity(
            displayCapacity,
            field: .displayEventCapacity
        )
        inputEventCapacity = try EventStreamCapacity(
            inputCapacity,
            field: .inputEventCapacity
        )
        overflowPolicy = policy
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
    public var rawInputQueueCapacity: InputQueueCapacity
    public var pendingInputEventCapacity: InputQueueCapacity
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
        rawInputQueueCapacity rawCapacity: InputQueueCapacity = .defaultRawInput,
        pendingInputEventCapacity pendingCapacity: InputQueueCapacity = .defaultPendingInput,
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
        rawInputQueueCapacity rawCapacity: InputQueueCapacity = .defaultRawInput,
        pendingInputEventCapacity pendingCapacity: InputQueueCapacity = .defaultPendingInput
    ) {
        rawInputQueueCapacity = rawCapacity
        pendingInputEventCapacity = pendingCapacity
        motionCoalescing = coalescingPolicy
    }

    public init(
        rawInputQueueCapacity rawCapacity: Int,
        pendingInputEventCapacity pendingCapacity: Int =
            InputQueueCapacity.defaultPendingInput.rawValue,
        pointerMotionCoalescing shouldCoalescePointerMotion: Bool = true,
        touchMotionCoalescing shouldCoalesceTouchMotion: Bool = true
    ) throws {
        rawInputQueueCapacity = try InputQueueCapacity(
            rawCapacity,
            field: .rawInputQueueCapacity
        )
        pendingInputEventCapacity = try InputQueueCapacity(
            pendingCapacity,
            field: .pendingInputEventCapacity
        )
        motionCoalescing = []
        pointerMotionCoalescing = shouldCoalescePointerMotion
        touchMotionCoalescing = shouldCoalesceTouchMotion
    }

    public init(
        pendingInputEventCapacity pendingCapacity: Int,
        rawInputQueueCapacity rawCapacity: Int = InputQueueCapacity.defaultRawInput.rawValue,
        pointerMotionCoalescing shouldCoalescePointerMotion: Bool = true,
        touchMotionCoalescing shouldCoalesceTouchMotion: Bool = true
    ) throws {
        rawInputQueueCapacity = try InputQueueCapacity(
            rawCapacity,
            field: .rawInputQueueCapacity
        )
        pendingInputEventCapacity = try InputQueueCapacity(
            pendingCapacity,
            field: .pendingInputEventCapacity
        )
        motionCoalescing = []
        pointerMotionCoalescing = shouldCoalescePointerMotion
        touchMotionCoalescing = shouldCoalesceTouchMotion
    }
}

public struct DiagnosticsConfiguration: Equatable, Sendable {
    public var capacity: DiagnosticsCapacity

    public init(capacity diagnosticsCapacity: DiagnosticsCapacity = .default) {
        capacity = diagnosticsCapacity
    }

    public init(capacity diagnosticsCapacity: Int) throws {
        capacity = try DiagnosticsCapacity(diagnosticsCapacity)
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
}
