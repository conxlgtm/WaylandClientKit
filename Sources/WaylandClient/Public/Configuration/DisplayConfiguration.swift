public struct EventStreamConfiguration: Equatable, Sendable {
    public var displayEventCapacity: EventStreamCapacity
    public var inputEventCapacity: EventStreamCapacity
    public var dataTransferEventCapacity: EventStreamCapacity

    public init(
        displayEventCapacity displayCapacity: EventStreamCapacity = .defaultDisplayEvents,
        inputEventCapacity inputCapacity: EventStreamCapacity = .defaultInputEvents,
        dataTransferEventCapacity dataTransferCapacity: EventStreamCapacity =
            .defaultDataTransferEvents
    ) {
        displayEventCapacity = displayCapacity
        inputEventCapacity = inputCapacity
        dataTransferEventCapacity = dataTransferCapacity
    }

    public init(
        displayEventCapacity displayCapacity: Int,
        inputEventCapacity inputCapacity: Int = EventStreamCapacity.defaultInputEvents.rawValue,
        dataTransferEventCapacity dataTransferCapacity: Int =
            EventStreamCapacity.defaultDataTransferEvents.rawValue
    ) throws {
        displayEventCapacity = try EventStreamCapacity(
            displayCapacity,
            field: .displayEventCapacity
        )
        inputEventCapacity = try EventStreamCapacity(
            inputCapacity,
            field: .inputEventCapacity
        )
        dataTransferEventCapacity = try EventStreamCapacity(
            dataTransferCapacity,
            field: .dataTransferEventCapacity
        )
    }

    public init(
        inputEventCapacity inputCapacity: Int,
        displayEventCapacity displayCapacity: Int =
            EventStreamCapacity.defaultDisplayEvents.rawValue,
        dataTransferEventCapacity dataTransferCapacity: Int =
            EventStreamCapacity.defaultDataTransferEvents.rawValue
    ) throws {
        displayEventCapacity = try EventStreamCapacity(
            displayCapacity,
            field: .displayEventCapacity
        )
        inputEventCapacity = try EventStreamCapacity(
            inputCapacity,
            field: .inputEventCapacity
        )
        dataTransferEventCapacity = try EventStreamCapacity(
            dataTransferCapacity,
            field: .dataTransferEventCapacity
        )
    }

    public init(
        dataTransferEventCapacity dataTransferCapacity: Int,
        displayEventCapacity displayCapacity: Int =
            EventStreamCapacity.defaultDisplayEvents.rawValue,
        inputEventCapacity inputCapacity: Int = EventStreamCapacity.defaultInputEvents.rawValue
    ) throws {
        displayEventCapacity = try EventStreamCapacity(
            displayCapacity,
            field: .displayEventCapacity
        )
        inputEventCapacity = try EventStreamCapacity(
            inputCapacity,
            field: .inputEventCapacity
        )
        dataTransferEventCapacity = try EventStreamCapacity(
            dataTransferCapacity,
            field: .dataTransferEventCapacity
        )
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

public struct KeyboardInterpretationConfiguration: Equatable, Sendable {
    public var compose: KeyboardComposeConfiguration

    public init(compose composeConfiguration: KeyboardComposeConfiguration = .enabled()) {
        compose = composeConfiguration
    }
}

public enum KeyboardComposeConfiguration: Equatable, Sendable {
    case disabled
    case enabled(
        locale: KeyboardComposeLocale = .processEnvironment,
        cancellationPolicy: KeyboardComposeCancellationPolicy = .passThroughCancellingKey
    )
}

public enum KeyboardComposeLocale: Equatable, Sendable {
    case processEnvironment
    case identifier(KeyboardComposeLocaleIdentifier)
}

public enum KeyboardComposeLocaleError: Error, Equatable, Sendable {
    case emptyIdentifier
}

public struct KeyboardComposeLocaleIdentifier: Equatable, Sendable {
    public let rawValue: String

    public init(_ value: String) throws(KeyboardComposeLocaleError) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw .emptyIdentifier
        }

        rawValue = trimmed
    }

    public static let posixC = Self(unchecked: "C")

    private init(unchecked value: String) {
        rawValue = value
    }
}

public enum KeyboardComposeCancellationPolicy: Equatable, Sendable {
    case passThroughCancellingKey
    case swallowCancellingKey
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
    public var keyboardInterpretation: KeyboardInterpretationConfiguration
    public var diagnostics: DiagnosticsConfiguration

    public init(
        eventStreams streamConfiguration: EventStreamConfiguration = .init(),
        inputPipeline inputConfiguration: InputPipelineConfiguration = .init(),
        keyboardInterpretation keyboardInterpretationConfiguration:
            KeyboardInterpretationConfiguration = .init(),
        diagnostics diagnosticsConfiguration: DiagnosticsConfiguration = .init()
    ) {
        eventStreams = streamConfiguration
        inputPipeline = inputConfiguration
        keyboardInterpretation = keyboardInterpretationConfiguration
        diagnostics = diagnosticsConfiguration
    }
}
