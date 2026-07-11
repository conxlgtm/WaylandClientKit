public struct EventStreamConfiguration: Equatable, Sendable {
    private struct ValidatedCapacities {
        var display: EventStreamCapacity
        var input: EventStreamCapacity
        var textInput: EventStreamCapacity
        var dataTransfer: EventStreamCapacity
        var presentation: EventStreamCapacity
    }

    public var displayEventCapacity: EventStreamCapacity
    public var inputEventCapacity: EventStreamCapacity
    public var textInputEventCapacity: EventStreamCapacity
    public var dataTransferEventCapacity: EventStreamCapacity
    public var presentationEventCapacity: EventStreamCapacity

    public init(
        displayEventCapacity displayCapacity: EventStreamCapacity = .defaultDisplayEvents,
        inputEventCapacity inputCapacity: EventStreamCapacity = .defaultInputEvents,
        textInputEventCapacity textInputCapacity: EventStreamCapacity =
            .defaultTextInputEvents,
        dataTransferEventCapacity dataTransferCapacity: EventStreamCapacity =
            .defaultDataTransferEvents,
        presentationEventCapacity presentationCapacity: EventStreamCapacity =
            .defaultPresentationEvents
    ) {
        displayEventCapacity = displayCapacity
        inputEventCapacity = inputCapacity
        textInputEventCapacity = textInputCapacity
        dataTransferEventCapacity = dataTransferCapacity
        presentationEventCapacity = presentationCapacity
    }

    public init(
        displayEventCapacity displayCapacity: Int,
        inputEventCapacity inputCapacity: Int = EventStreamCapacity.defaultInputEvents.rawValue,
        textInputEventCapacity textInputCapacity: Int =
            EventStreamCapacity.defaultTextInputEvents.rawValue,
        dataTransferEventCapacity dataTransferCapacity: Int =
            EventStreamCapacity.defaultDataTransferEvents.rawValue,
        presentationEventCapacity presentationCapacity: Int =
            EventStreamCapacity.defaultPresentationEvents.rawValue
    ) throws {
        self.init(
            try Self.validatedCapacities(
                displayCapacity,
                inputCapacity,
                textInputCapacity,
                dataTransferCapacity,
                presentationCapacity
            ))
    }

    public init(
        inputEventCapacity inputCapacity: Int,
        displayEventCapacity displayCapacity: Int =
            EventStreamCapacity.defaultDisplayEvents.rawValue,
        textInputEventCapacity textInputCapacity: Int =
            EventStreamCapacity.defaultTextInputEvents.rawValue,
        dataTransferEventCapacity dataTransferCapacity: Int =
            EventStreamCapacity.defaultDataTransferEvents.rawValue,
        presentationEventCapacity presentationCapacity: Int =
            EventStreamCapacity.defaultPresentationEvents.rawValue
    ) throws {
        self.init(
            try Self.validatedCapacities(
                displayCapacity,
                inputCapacity,
                textInputCapacity,
                dataTransferCapacity,
                presentationCapacity
            ))
    }

    public init(
        textInputEventCapacity textInputCapacity: Int,
        displayEventCapacity displayCapacity: Int =
            EventStreamCapacity.defaultDisplayEvents.rawValue,
        inputEventCapacity inputCapacity: Int = EventStreamCapacity.defaultInputEvents.rawValue,
        dataTransferEventCapacity dataTransferCapacity: Int =
            EventStreamCapacity.defaultDataTransferEvents.rawValue,
        presentationEventCapacity presentationCapacity: Int =
            EventStreamCapacity.defaultPresentationEvents.rawValue
    ) throws {
        self.init(
            try Self.validatedCapacities(
                displayCapacity,
                inputCapacity,
                textInputCapacity,
                dataTransferCapacity,
                presentationCapacity
            ))
    }

    public init(
        dataTransferEventCapacity dataTransferCapacity: Int,
        displayEventCapacity displayCapacity: Int =
            EventStreamCapacity.defaultDisplayEvents.rawValue,
        inputEventCapacity inputCapacity: Int = EventStreamCapacity.defaultInputEvents.rawValue,
        textInputEventCapacity textInputCapacity: Int =
            EventStreamCapacity.defaultTextInputEvents.rawValue,
        presentationEventCapacity presentationCapacity: Int =
            EventStreamCapacity.defaultPresentationEvents.rawValue
    ) throws {
        self.init(
            try Self.validatedCapacities(
                displayCapacity,
                inputCapacity,
                textInputCapacity,
                dataTransferCapacity,
                presentationCapacity
            ))
    }

    public init(
        presentationEventCapacity presentationCapacity: Int,
        displayEventCapacity displayCapacity: Int =
            EventStreamCapacity.defaultDisplayEvents.rawValue,
        inputEventCapacity inputCapacity: Int = EventStreamCapacity.defaultInputEvents.rawValue,
        textInputEventCapacity textInputCapacity: Int =
            EventStreamCapacity.defaultTextInputEvents.rawValue,
        dataTransferEventCapacity dataTransferCapacity: Int =
            EventStreamCapacity.defaultDataTransferEvents.rawValue
    ) throws {
        self.init(
            try Self.validatedCapacities(
                displayCapacity,
                inputCapacity,
                textInputCapacity,
                dataTransferCapacity,
                presentationCapacity
            ))
    }

    private init(_ capacities: ValidatedCapacities) {
        self.init(
            displayEventCapacity: capacities.display,
            inputEventCapacity: capacities.input,
            textInputEventCapacity: capacities.textInput,
            dataTransferEventCapacity: capacities.dataTransfer,
            presentationEventCapacity: capacities.presentation
        )
    }

    private static func validatedCapacities(
        _ displayCapacity: Int,
        _ inputCapacity: Int,
        _ textInputCapacity: Int,
        _ dataTransferCapacity: Int,
        _ presentationCapacity: Int
    ) throws -> ValidatedCapacities {
        ValidatedCapacities(
            display: try EventStreamCapacity(
                displayCapacity,
                field: .displayEventCapacity
            ),
            input: try EventStreamCapacity(
                inputCapacity,
                field: .inputEventCapacity
            ),
            textInput: try EventStreamCapacity(
                textInputCapacity,
                field: .textInputEventCapacity
            ),
            dataTransfer: try EventStreamCapacity(
                dataTransferCapacity,
                field: .dataTransferEventCapacity
            ),
            presentation: try EventStreamCapacity(
                presentationCapacity,
                field: .presentationEventCapacity
            )
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
    private struct ValidatedCapacities {
        var raw: InputQueueCapacity
        var pending: InputQueueCapacity
    }

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
        let capacities = try Self.validatedCapacities(
            rawCapacity,
            pendingCapacity
        )
        self.init(
            rawInputQueueCapacity: capacities.raw,
            pendingInputEventCapacity: capacities.pending,
            pointerMotionCoalescing: shouldCoalescePointerMotion,
            touchMotionCoalescing: shouldCoalesceTouchMotion
        )
    }

    public init(
        pendingInputEventCapacity pendingCapacity: Int,
        rawInputQueueCapacity rawCapacity: Int = InputQueueCapacity.defaultRawInput.rawValue,
        pointerMotionCoalescing shouldCoalescePointerMotion: Bool = true,
        touchMotionCoalescing shouldCoalesceTouchMotion: Bool = true
    ) throws {
        let capacities = try Self.validatedCapacities(
            rawCapacity,
            pendingCapacity
        )
        self.init(
            rawInputQueueCapacity: capacities.raw,
            pendingInputEventCapacity: capacities.pending,
            pointerMotionCoalescing: shouldCoalescePointerMotion,
            touchMotionCoalescing: shouldCoalesceTouchMotion
        )
    }

    private static func validatedCapacities(
        _ rawCapacity: Int,
        _ pendingCapacity: Int
    ) throws -> ValidatedCapacities {
        ValidatedCapacities(
            raw: try InputQueueCapacity(
                rawCapacity,
                field: .rawInputQueueCapacity
            ),
            pending: try InputQueueCapacity(
                pendingCapacity,
                field: .pendingInputEventCapacity
            )
        )
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
    case containsNUL
}

public struct KeyboardComposeLocaleIdentifier: Equatable, Sendable {
    public let rawValue: String

    public init(_ value: String) throws(KeyboardComposeLocaleError) {
        let trimmed = trimmingKeyboardComposeASCIIWhitespace(value)
        guard !trimmed.isEmpty else {
            throw .emptyIdentifier
        }
        guard !trimmed.utf8.contains(0) else {
            throw .containsNUL
        }

        rawValue = trimmed
    }

    public static let posixC = Self(unchecked: "C")

    private init(unchecked value: String) {
        precondition(!value.isEmpty, "compose locale identifier must not be empty")
        precondition(
            !value.utf8.contains(0),
            "compose locale identifier must not contain NUL bytes"
        )
        rawValue = value
    }
}

private func trimmingKeyboardComposeASCIIWhitespace(_ value: String) -> String {
    let trimmedScalars = value.unicodeScalars.drop { scalar in
        isKeyboardComposeASCIIWhitespace(scalar)
    }
    .reversed()
    .drop { isKeyboardComposeASCIIWhitespace($0) }
    .reversed()
    return String(String.UnicodeScalarView(trimmedScalars))
}

private func isKeyboardComposeASCIIWhitespace(_ scalar: UnicodeScalar) -> Bool {
    switch scalar.value {
    case 0x09...0x0D, 0x20:
        true
    default:
        false
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
    public var applicationID: NonEmptyWaylandString
    public var eventStreams: EventStreamConfiguration
    public var inputPipeline: InputPipelineConfiguration
    public var keyboardInterpretation: KeyboardInterpretationConfiguration
    public var diagnostics: DiagnosticsConfiguration

    public init(
        applicationID displayApplicationID: NonEmptyWaylandString,
        eventStreams streamConfiguration: EventStreamConfiguration = .init(),
        inputPipeline inputConfiguration: InputPipelineConfiguration = .init(),
        keyboardInterpretation keyboardInterpretationConfiguration:
            KeyboardInterpretationConfiguration = .init(),
        diagnostics diagnosticsConfiguration: DiagnosticsConfiguration = .init()
    ) {
        applicationID = displayApplicationID
        eventStreams = streamConfiguration
        inputPipeline = inputConfiguration
        keyboardInterpretation = keyboardInterpretationConfiguration
        diagnostics = diagnosticsConfiguration
    }

    public init(
        applicationID displayApplicationID: String,
        eventStreams streamConfiguration: EventStreamConfiguration = .init(),
        inputPipeline inputConfiguration: InputPipelineConfiguration = .init(),
        keyboardInterpretation keyboardInterpretationConfiguration:
            KeyboardInterpretationConfiguration = .init(),
        diagnostics diagnosticsConfiguration: DiagnosticsConfiguration = .init()
    ) throws {
        try self.init(
            applicationID: NonEmptyWaylandString(displayApplicationID),
            eventStreams: streamConfiguration,
            inputPipeline: inputConfiguration,
            keyboardInterpretation: keyboardInterpretationConfiguration,
            diagnostics: diagnosticsConfiguration
        )
    }
}
