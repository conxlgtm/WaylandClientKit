public struct PresentationTimestamp: Equatable, Sendable {
    public let seconds: UInt64
    public let nanoseconds: UInt32

    package init(seconds timestampSeconds: UInt64, nanoseconds timestampNanoseconds: UInt32) {
        seconds = timestampSeconds
        nanoseconds = timestampNanoseconds
    }
}

public struct PresentationSequence: Equatable, Sendable {
    public let value: UInt64

    public init(value sequenceValue: UInt64) {
        value = sequenceValue
    }
}

public struct PresentationFeedbackFlags: OptionSet, Equatable, Sendable, Hashable {
    public let rawValue: UInt32

    public init(rawValue flagsRawValue: UInt32) {
        rawValue = flagsRawValue
    }

    public static let vsync = PresentationFeedbackFlags(rawValue: 0x1)
    public static let hardwareClock = PresentationFeedbackFlags(rawValue: 0x2)
    public static let hardwareCompletion = PresentationFeedbackFlags(rawValue: 0x4)
    public static let zeroCopy = PresentationFeedbackFlags(rawValue: 0x8)
}

public enum SurfacePresentationFeedback: Equatable, Sendable {
    case presented(PresentationFeedback)
    case discarded(SurfacePresentationIdentity)

    public var surface: SurfacePresentationIdentity {
        switch self {
        case .presented(let feedback):
            feedback.surface
        case .discarded(let identity):
            identity
        }
    }
}

public struct PresentationFeedback: Equatable, Sendable {
    public let surface: SurfacePresentationIdentity
    public let timestamp: PresentationTimestamp
    public let refreshNanoseconds: UInt32?
    public let sequence: PresentationSequence
    public let flags: PresentationFeedbackFlags
    public let synchronizedOutput: OutputID?

    public init(
        surface feedbackSurface: SurfacePresentationIdentity,
        timestamp feedbackTimestamp: PresentationTimestamp,
        refreshNanoseconds feedbackRefreshNanoseconds: UInt32?,
        sequence feedbackSequence: PresentationSequence,
        flags feedbackFlags: PresentationFeedbackFlags,
        synchronizedOutput feedbackSynchronizedOutput: OutputID?
    ) {
        surface = feedbackSurface
        timestamp = feedbackTimestamp
        refreshNanoseconds = feedbackRefreshNanoseconds
        sequence = feedbackSequence
        flags = feedbackFlags
        synchronizedOutput = feedbackSynchronizedOutput
    }
}

/// Presentation feedback correlated to its managed surface.
public struct ManagedSurfacePresentationEvent: Equatable, Sendable {
    /// The window, popup, or subsurface that owned the committed feedback request.
    public let surface: ManagedSurfaceIdentity
    /// The compositor's result for the committed request.
    public let feedback: SurfacePresentationFeedback

    /// Creates a managed-surface presentation event.
    public init(
        surface eventSurface: ManagedSurfaceIdentity,
        feedback eventFeedback: SurfacePresentationFeedback
    ) {
        surface = eventSurface
        feedback = eventFeedback
    }
}

/// A managed-surface-scoped presentation-feedback convenience stream.
///
/// This stream preserves presentation order for its surface, but not ordering
/// relative to other event families. Use ``DisplayEvents`` when cross-family
/// ordering matters.
@safe
public struct ManagedSurfacePresentationEvents: AsyncSequence, Sendable {
    public typealias Element = SurfacePresentationFeedback
    public typealias Failure = WaylandDisplayError

    private let surface: ManagedSurfaceIdentity
    private let subscriptions: InternalEventSubscriptionFactory<ManagedSurfacePresentationEvent>

    package init(
        surface eventsSurface: ManagedSurfaceIdentity,
        subscriptions eventSubscriptions:
            InternalEventSubscriptionFactory<ManagedSurfacePresentationEvent>
    ) {
        surface = eventsSurface
        subscriptions = eventSubscriptions
    }

    public func makeAsyncIterator() -> ManagedSurfacePresentationEventsIterator {
        ManagedSurfacePresentationEventsIterator(
            surface: surface,
            base: subscriptions.makeAsyncIterator()
        )
    }
}

/// An iterator over presentation feedback for one managed surface.
@safe
public struct ManagedSurfacePresentationEventsIterator: AsyncIteratorProtocol {
    public typealias Element = SurfacePresentationFeedback
    public typealias Failure = WaylandDisplayError

    private let surface: ManagedSurfaceIdentity
    private var base: InternalEventSubscriptionIterator<ManagedSurfacePresentationEvent>

    package init(
        surface iteratorSurface: ManagedSurfaceIdentity,
        base iterator: InternalEventSubscriptionIterator<ManagedSurfacePresentationEvent>
    ) {
        surface = iteratorSurface
        base = iterator
    }

    /// Returns the next feedback result for the selected surface.
    public mutating func next() async throws(WaylandDisplayError) -> SurfacePresentationFeedback? {
        try await next(isolation: nil)
    }

    /// Returns the next result while preserving the caller's isolation context.
    public mutating func next(
        isolation actor: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> SurfacePresentationFeedback? {
        while let event = try await base.next(isolation: actor) {
            guard event.surface == surface else { continue }
            return event.feedback
        }

        return nil
    }
}
