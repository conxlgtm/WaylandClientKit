import Synchronization
import WaylandRaw

public enum DisplayEvent: Equatable, Sendable {
    case input(InputEvent)
    case diagnostic(DisplayDiagnostic)
    case windowCloseRequested(WindowID)
    case windowClosed(WindowID)
    case redrawRequested(WindowID)
}

public enum DiagnosticSeverity: Equatable, Sendable {
    case warning
    case degraded
    case error
}

public enum DisplayDiagnostic: Equatable, Sendable {
    case input(InputDiagnostic, severity: DiagnosticSeverity)
}

public enum EventStreamOverflowPolicy: Equatable, Sendable {
    case failFast
}

public struct EventStreamConfiguration: Equatable, Sendable {
    public var displayEventCapacity: Int
    public var inputEventCapacity: Int
    public var overflowPolicy: EventStreamOverflowPolicy

    public init(
        displayEventCapacity displayCapacity: Int = 256,
        inputEventCapacity inputCapacity: Int = 512,
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

public enum WaylandDisplayError: Error, Equatable, Sendable, CustomStringConvertible {
    case closed
    case protocolError(interface: String?, objectID: UInt32, code: Int32)
    case systemError(errno: Int32)
    case runtime(String)
    case eventSubscriberOverflow(stream: String, capacity: Int)
    case internalInvariantViolation(String)

    init(_ error: any Error) {
        if let displayError = error as? WaylandDisplayError {
            self = displayError
            return
        }

        if let runtimeError = error as? RuntimeError {
            self = Self(runtimeError)
            return
        }

        self = .runtime(String(describing: error))
    }

    init(_ runtimeError: RuntimeError) {
        switch runtimeError {
        case .protocolError(let interfaceName, let objectID, let code):
            self = .protocolError(interface: interfaceName, objectID: objectID, code: code)
        case .pollFailed(let errno), .systemError(let errno):
            self = .systemError(errno: errno)
        default:
            self = .runtime(runtimeError.description)
        }
    }

    public var description: String {
        switch self {
        case .closed:
            "Wayland display is closed"
        case .protocolError(let interface, let objectID, let code):
            "Wayland protocol error interface=\(interface ?? "?") object=\(objectID) code=\(code)"
        case .systemError(let errno):
            "Wayland display failed with errno \(errno)"
        case .runtime(let detail):
            "Wayland display failed: \(detail)"
        case .eventSubscriberOverflow(let stream, let capacity):
            "Wayland \(stream) subscriber exceeded buffer capacity \(capacity)"
        case .internalInvariantViolation(let detail):
            "Wayland display internal invariant failed: \(detail)"
        }
    }
}

@safe
package struct InternalEventSubscription<Element: Sendable>: Sendable {
    private let subscription: EventSubscription<Element>

    init(_ eventSubscription: EventSubscription<Element>) {
        subscription = eventSubscription
    }

    package func makeAsyncIterator() -> InternalEventSubscriptionIterator<Element> {
        InternalEventSubscriptionIterator(subscription: subscription)
    }
}

@safe
package struct InternalEventSubscriptionIterator<Element: Sendable>: AsyncIteratorProtocol {
    package typealias Failure = WaylandDisplayError

    private let subscription: EventSubscription<Element>

    init(subscription eventSubscription: EventSubscription<Element>) {
        subscription = eventSubscription
    }

    package mutating func next() async throws(WaylandDisplayError) -> Element? {
        try await next(isolation: nil)
    }

    package mutating func next(
        isolation actor: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> Element? {
        try await subscription.next(isolation: actor)
    }
}

@safe
public struct DisplayEvents: AsyncSequence, Sendable {
    public typealias Element = DisplayEvent
    public typealias Failure = WaylandDisplayError

    private let subscription: InternalEventSubscription<DisplayEvent>

    package init(_ eventSubscription: InternalEventSubscription<DisplayEvent>) {
        subscription = eventSubscription
    }

    public func makeAsyncIterator() -> DisplayEventsIterator {
        DisplayEventsIterator(base: subscription.makeAsyncIterator())
    }
}

@safe
public struct DisplayEventsIterator: AsyncIteratorProtocol {
    public typealias Element = DisplayEvent
    public typealias Failure = WaylandDisplayError

    private var base: InternalEventSubscriptionIterator<DisplayEvent>

    package init(base iterator: InternalEventSubscriptionIterator<DisplayEvent>) {
        base = iterator
    }

    public mutating func next() async throws(WaylandDisplayError) -> DisplayEvent? {
        try await next(isolation: nil)
    }

    public mutating func next(
        isolation actor: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> DisplayEvent? {
        try await base.next(isolation: actor)
    }
}

@safe
public struct InputEvents: AsyncSequence, Sendable {
    public typealias Element = InputEvent
    public typealias Failure = WaylandDisplayError

    private let subscription: InternalEventSubscription<InputEvent>

    package init(_ eventSubscription: InternalEventSubscription<InputEvent>) {
        subscription = eventSubscription
    }

    public func makeAsyncIterator() -> InputEventsIterator {
        InputEventsIterator(base: subscription.makeAsyncIterator())
    }
}

@safe
public struct InputEventsIterator: AsyncIteratorProtocol {
    public typealias Element = InputEvent
    public typealias Failure = WaylandDisplayError

    private var base: InternalEventSubscriptionIterator<InputEvent>

    package init(base iterator: InternalEventSubscriptionIterator<InputEvent>) {
        base = iterator
    }

    public mutating func next() async throws(WaylandDisplayError) -> InputEvent? {
        try await next(isolation: nil)
    }

    public mutating func next(
        isolation actor: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> InputEvent? {
        try await base.next(isolation: actor)
    }
}

@safe
final class DisplayEventHub: Sendable {
    private let displayBroker: TypedEventBroker<DisplayEvent>
    private let inputBroker: TypedEventBroker<InputEvent>

    init(configuration: EventStreamConfiguration = .init()) {
        displayBroker = TypedEventBroker<DisplayEvent>(
            streamName: "display event",
            capacity: configuration.displayEventCapacity
        )
        inputBroker = TypedEventBroker<InputEvent>(
            streamName: "input event",
            capacity: configuration.inputEventCapacity
        )
    }

    func displayEvents() -> DisplayEvents {
        DisplayEvents(displayBroker.subscribe())
    }

    func inputEvents() -> InputEvents {
        InputEvents(inputBroker.subscribe())
    }

    func publish(_ event: DisplayEvent) {
        switch event {
        case .input(let inputEvent):
            publishInput(inputEvent)
        case .diagnostic, .windowCloseRequested, .windowClosed, .redrawRequested:
            displayBroker.publish(event)
        }
    }

    func publishInput(_ inputEvent: InputEvent) {
        switch inputEvent.kind {
        case .diagnostic(let diagnostic):
            displayBroker.publish(
                .diagnostic(
                    .input(diagnostic, severity: displaySeverity(for: diagnostic))
                )
            )
        case .seat, .pointer, .keyboard, .touch:
            displayBroker.publish(.input(inputEvent))
        }

        inputBroker.publish(inputEvent)
    }

    func finish(throwing error: WaylandDisplayError? = nil) {
        displayBroker.finish(throwing: error)
        inputBroker.finish(throwing: error)
    }

    private func displaySeverity(for diagnostic: InputDiagnostic) -> DiagnosticSeverity {
        switch diagnostic.operation {
        case .queueOverflow:
            .error
        case .keyboardKeymap, .listener, .cursor:
            .degraded
        }
    }
}

typealias EventWaiter<Element: Sendable> =
    CheckedContinuation<Result<Element?, WaylandDisplayError>, Never>

@safe
final class EventSubscription<Element: Sendable>: Sendable {
    private let broker: TypedEventBroker<Element>
    private let id: Int

    init(broker eventBroker: TypedEventBroker<Element>, id subscriberID: Int) {
        broker = eventBroker
        id = subscriberID
    }

    deinit {
        broker.cancelSubscriber(id)
    }

    func next(
        isolation _: isolated (any Actor)?
    ) async throws(WaylandDisplayError) -> Element? {
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                broker.enqueueOrResumeNext(subscriberID: id, continuation: continuation)
            }
        } onCancel: {
            broker.cancelSubscriber(id)
        }

        switch result {
        case .success(let element):
            return element
        case .failure(let error):
            throw error
        }
    }
}

@safe
final class TypedEventBroker<Element: Sendable>: Sendable {
    private struct Subscriber {
        var buffer: [Element] = []
        var waiter: EventWaiter<Element>?
        var terminalError: WaylandDisplayError?
        var isTerminal = false
    }

    private struct BrokerState {
        var nextID = 1
        var subscribers: [Int: Subscriber] = [:]
        var terminalError: WaylandDisplayError?
        var isTerminal = false
    }

    private let streamName: String
    private let capacity: Int
    private let state = Mutex(BrokerState())

    init(streamName eventStreamName: String, capacity eventCapacity: Int) {
        streamName = eventStreamName
        capacity = eventCapacity
    }

    func subscribe() -> InternalEventSubscription<Element> {
        let subscriberID = state.withLock { brokerState in
            let id = brokerState.nextID
            brokerState.nextID += 1
            brokerState.subscribers[id] = Subscriber()
            return id
        }

        return InternalEventSubscription(EventSubscription(broker: self, id: subscriberID))
    }

    func publish(_ element: Element) {
        let waiters: [(EventWaiter<Element>, Result<Element?, WaylandDisplayError>)] =
            state.withLock { brokerState in
                guard !brokerState.isTerminal else { return [] }

                var resumedWaiters:
                    [(EventWaiter<Element>, Result<Element?, WaylandDisplayError>)] =
                        []
                let overflowError = WaylandDisplayError.eventSubscriberOverflow(
                    stream: streamName,
                    capacity: capacity
                )

                for subscriberID in brokerState.subscribers.keys.sorted() {
                    guard var subscriber = brokerState.subscribers[subscriberID],
                        !subscriber.isTerminal
                    else { continue }

                    if let waiter = subscriber.waiter {
                        subscriber.waiter = nil
                        brokerState.subscribers[subscriberID] = subscriber
                        resumedWaiters.append((waiter, .success(element)))
                        continue
                    }

                    if subscriber.buffer.count < capacity {
                        subscriber.buffer.append(element)
                    } else {
                        subscriber.buffer.removeAll()
                        subscriber.isTerminal = true
                        subscriber.terminalError = overflowError
                    }
                    brokerState.subscribers[subscriberID] = subscriber
                }

                return resumedWaiters
            }

        resume(waiters)
    }

    func finish(throwing error: WaylandDisplayError? = nil) {
        let waiters: [(EventWaiter<Element>, Result<Element?, WaylandDisplayError>)] =
            state.withLock { brokerState in
                guard !brokerState.isTerminal else { return [] }

                brokerState.isTerminal = true
                brokerState.terminalError = error

                var resumedWaiters:
                    [(EventWaiter<Element>, Result<Element?, WaylandDisplayError>)] =
                        []
                for subscriberID in brokerState.subscribers.keys {
                    guard var subscriber = brokerState.subscribers[subscriberID],
                        let waiter = subscriber.waiter
                    else { continue }

                    subscriber.waiter = nil
                    brokerState.subscribers.removeValue(forKey: subscriberID)
                    resumedWaiters.append((waiter, Self.terminalResult(error)))
                }

                return resumedWaiters
            }

        resume(waiters)
    }

    func enqueueOrResumeNext(
        subscriberID: Int,
        continuation: EventWaiter<Element>
    ) {
        let immediate = state.withLock { brokerState -> Result<Element?, WaylandDisplayError>? in
            guard var subscriber = brokerState.subscribers[subscriberID] else {
                return .success(nil)
            }

            if !subscriber.buffer.isEmpty {
                let element = subscriber.buffer.removeFirst()
                brokerState.subscribers[subscriberID] = subscriber
                return .success(element)
            }

            if subscriber.isTerminal {
                brokerState.subscribers.removeValue(forKey: subscriberID)
                return Self.terminalResult(subscriber.terminalError)
            }

            if brokerState.isTerminal {
                brokerState.subscribers.removeValue(forKey: subscriberID)
                return Self.terminalResult(brokerState.terminalError)
            }

            guard subscriber.waiter == nil else {
                return .failure(.internalInvariantViolation("event subscriber awaited twice"))
            }

            subscriber.waiter = continuation
            brokerState.subscribers[subscriberID] = subscriber
            return nil
        }

        if let immediate {
            continuation.resume(returning: immediate)
        }
    }

    func cancelSubscriber(_ subscriberID: Int) {
        let waiter = state.withLock { brokerState in
            brokerState.subscribers.removeValue(forKey: subscriberID)?.waiter
        }

        waiter?.resume(returning: .success(nil))
    }

    private static func terminalResult(
        _ error: WaylandDisplayError?
    ) -> Result<Element?, WaylandDisplayError> {
        if let error {
            return .failure(error)
        }

        return .success(nil)
    }

    private func resume(
        _ waiters: [(EventWaiter<Element>, Result<Element?, WaylandDisplayError>)]
    ) {
        for (waiter, result) in waiters {
            waiter.resume(returning: result)
        }
    }
}
