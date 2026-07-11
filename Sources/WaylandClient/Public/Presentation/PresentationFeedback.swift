public struct PresentationTimestamp: Equatable, Sendable {
    public let seconds: UInt64
    public let nanoseconds: UInt32

    public init(seconds timestampSeconds: UInt64, nanoseconds timestampNanoseconds: UInt32) {
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

public struct SurfacePresentationIdentity:
    Equatable,
    Hashable,
    Sendable,
    CustomStringConvertible
{
    package let rawValue: UInt64

    package init(rawValue identityRawValue: UInt64) {
        rawValue = identityRawValue
    }

    public var description: String {
        "presentation-\(rawValue)"
    }
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

package struct WindowPresentationEvent: Equatable, Sendable {
    package let windowID: WindowID
    package let feedback: SurfacePresentationFeedback

    package init(
        windowID eventWindowID: WindowID,
        feedback eventFeedback: SurfacePresentationFeedback
    ) {
        windowID = eventWindowID
        feedback = eventFeedback
    }
}

@safe
public struct WindowPresentationEvents: AsyncSequence, Sendable {
    public typealias Element = SurfacePresentationFeedback
    public typealias Failure = WaylandDisplayError

    private let windowID: WindowID
    private let subscriptions: InternalEventSubscriptionFactory<WindowPresentationEvent>

    package init(
        windowID eventsWindowID: WindowID,
        subscriptions eventSubscriptions: InternalEventSubscriptionFactory<WindowPresentationEvent>
    ) {
        windowID = eventsWindowID
        subscriptions = eventSubscriptions
    }

    public func makeAsyncIterator() -> WindowPresentationEventsIterator {
        WindowPresentationEventsIterator(
            windowID: windowID,
            base: subscriptions.makeAsyncIterator()
        )
    }
}

@safe
public struct WindowPresentationEventsIterator: AsyncIteratorProtocol {
    public typealias Element = SurfacePresentationFeedback
    public typealias Failure = WaylandDisplayError

    private let windowID: WindowID
    private var base: InternalEventSubscriptionIterator<WindowPresentationEvent>

    package init(
        windowID iteratorWindowID: WindowID,
        base iterator: InternalEventSubscriptionIterator<WindowPresentationEvent>
    ) {
        windowID = iteratorWindowID
        base = iterator
    }

    public mutating func next() async throws(WaylandDisplayError) -> SurfacePresentationFeedback? {
        try await next(isolation: nil)
    }

    public mutating func next(
        isolation actor: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> SurfacePresentationFeedback? {
        while let event = try await base.next(isolation: actor) {
            guard event.windowID == windowID else { continue }
            return event.feedback
        }

        return nil
    }
}
