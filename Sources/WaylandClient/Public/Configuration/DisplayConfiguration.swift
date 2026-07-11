public struct EventStreamConfiguration: Equatable, Sendable {
    public var displayEventCapacity: PositiveInt
    public var inputEventCapacity: PositiveInt
    public var textInputEventCapacity: PositiveInt
    public var dataTransferEventCapacity: PositiveInt
    public var presentationEventCapacity: PositiveInt

    public init(
        displayEventCapacity displayCapacity: PositiveInt = .defaultDisplayEventCapacity,
        inputEventCapacity inputCapacity: PositiveInt = .defaultInputEventCapacity,
        textInputEventCapacity textInputCapacity: PositiveInt = .defaultTextInputEventCapacity,
        dataTransferEventCapacity dataTransferCapacity: PositiveInt =
            .defaultDataTransferEventCapacity,
        presentationEventCapacity presentationCapacity: PositiveInt =
            .defaultPresentationEventCapacity
    ) {
        displayEventCapacity = displayCapacity
        inputEventCapacity = inputCapacity
        textInputEventCapacity = textInputCapacity
        dataTransferEventCapacity = dataTransferCapacity
        presentationEventCapacity = presentationCapacity
    }

    public init(
        displayEventCapacity displayCapacity: Int,
        inputEventCapacity inputCapacity: Int,
        textInputEventCapacity textInputCapacity: Int,
        dataTransferEventCapacity dataTransferCapacity: Int,
        presentationEventCapacity presentationCapacity: Int
    ) throws {
        try self.init(
            displayEventCapacity: PositiveInt(displayCapacity),
            inputEventCapacity: PositiveInt(inputCapacity),
            textInputEventCapacity: PositiveInt(textInputCapacity),
            dataTransferEventCapacity: PositiveInt(dataTransferCapacity),
            presentationEventCapacity: PositiveInt(presentationCapacity)
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
    public var rawInputQueueCapacity: PositiveInt
    public var pendingInputEventCapacity: PositiveInt
    public var motionCoalescing: InputMotionCoalescing

    public init(
        motionCoalescing coalescingPolicy: InputMotionCoalescing = .all,
        rawInputQueueCapacity rawCapacity: PositiveInt = .defaultRawInputQueueCapacity,
        pendingInputEventCapacity pendingCapacity: PositiveInt =
            .defaultPendingInputEventCapacity
    ) {
        rawInputQueueCapacity = rawCapacity
        pendingInputEventCapacity = pendingCapacity
        motionCoalescing = coalescingPolicy
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
    public var capacity: PositiveInt

    public init(capacity diagnosticsCapacity: PositiveInt = .defaultDiagnosticsCapacity) {
        capacity = diagnosticsCapacity
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
