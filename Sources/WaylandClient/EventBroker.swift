import Synchronization

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

enum OverflowStrategy<Element: Sendable>: Sendable {
    case failFast
    case dropOldest(makeNotice: @Sendable (Int) -> Element)
}

private enum StreamTermination {
    case finished
    case failed(WaylandDisplayError)

    init(error: WaylandDisplayError?) {
        if let error {
            self = .failed(error)
        } else {
            self = .finished
        }
    }

    func result<Element: Sendable>() -> Result<Element?, WaylandDisplayError> {
        switch self {
        case .finished:
            .success(nil)
        case .failed(let error):
            .failure(error)
        }
    }
}

private enum BrokerLifecycle {
    case open
    case terminal(StreamTermination)

    var isTerminal: Bool {
        if case .terminal = self {
            return true
        }

        return false
    }
}

private enum DropLedger<Element: Sendable> {
    case none
    case pending(count: Int)

    mutating func recordDrop() {
        let nextCount =
            switch self {
            case .none:
                1
            case .pending(let count):
                count + 1
            }
        self = .pending(count: nextCount)
    }

    mutating func takeNotice(
        overflowStrategy: OverflowStrategy<Element>
    ) -> Element? {
        guard case .pending(let count) = self else { return nil }
        guard case .dropOldest(let makeNotice) = overflowStrategy else {
            preconditionFailure("drop notice recorded for a fail-fast event stream")
        }

        self = .none
        return makeNotice(count)
    }
}

@safe
final class TypedEventBroker<Element: Sendable>: Sendable {
    private typealias Delivery = (EventWaiter<Element>, Result<Element?, WaylandDisplayError>)

    private enum SubscriberState {
        case open(buffer: [Element], drops: DropLedger<Element>)
        case waiting(EventWaiter<Element>, drops: DropLedger<Element>)
        case terminal(StreamTermination)
    }

    private struct Subscriber {
        var state: SubscriberState = .open(buffer: [], drops: .none)
    }

    private struct PublishContext {
        let capacity: Int
        let overflowError: WaylandDisplayError
        let overflowStrategy: OverflowStrategy<Element>
    }

    private struct BrokerState {
        var nextID = 1
        var subscribers: [Int: Subscriber] = [:]
        var lifecycle = BrokerLifecycle.open

        mutating func subscribe() -> Int {
            defer { nextID += 1 }
            subscribers[nextID] = Subscriber()
            return nextID
        }

        mutating func publish(
            _ element: Element,
            streamName: String,
            capacity: Int,
            overflowStrategy: OverflowStrategy<Element>
        ) -> [Delivery] {
            guard case .open = lifecycle else { return [] }

            let context = PublishContext(
                capacity: capacity,
                overflowError: WaylandDisplayError.eventSubscriberOverflow(
                    stream: streamName,
                    capacity: capacity
                ),
                overflowStrategy: overflowStrategy
            )
            var deliveries: [Delivery] = []

            for subscriberID in subscribers.keys.sorted() {
                guard var subscriber = subscribers[subscriberID] else { continue }
                publish(
                    element,
                    for: &subscriber,
                    context: context,
                    deliveries: &deliveries
                )

                subscribers[subscriberID] = subscriber
            }

            return deliveries
        }

        mutating func finish(throwing error: WaylandDisplayError?) -> [Delivery] {
            guard case .open = lifecycle else { return [] }

            let termination = StreamTermination(error: error)
            lifecycle = .terminal(termination)
            var deliveries: [Delivery] = []
            for subscriberID in subscribers.keys {
                guard let subscriber = subscribers[subscriberID] else { continue }
                if case .waiting(let waiter, _) = subscriber.state {
                    subscribers.removeValue(forKey: subscriberID)
                    deliveries.append((waiter, termination.result()))
                }
            }

            return deliveries
        }

        mutating func enqueueOrResumeNext(
            subscriberID: Int,
            continuation: EventWaiter<Element>,
            overflowStrategy: OverflowStrategy<Element>
        ) -> Result<Element?, WaylandDisplayError>? {
            guard var subscriber = subscribers[subscriberID] else {
                return .success(nil)
            }

            switch subscriber.state {
            case .open(var buffer, var drops):
                if !buffer.isEmpty {
                    let element = buffer.removeFirst()
                    subscriber.state = .open(buffer: buffer, drops: drops)
                    subscribers[subscriberID] = subscriber
                    return .success(element)
                }

                if let notice = drops.takeNotice(overflowStrategy: overflowStrategy) {
                    subscriber.state = .open(buffer: [], drops: drops)
                    subscribers[subscriberID] = subscriber
                    return .success(notice)
                }

                if case .terminal(let termination) = lifecycle {
                    subscribers.removeValue(forKey: subscriberID)
                    return termination.result()
                }

                subscriber.state = .waiting(continuation, drops: drops)
                subscribers[subscriberID] = subscriber
                return nil
            case .waiting:
                return .failure(.internalInvariantViolation("event subscriber awaited twice"))
            case .terminal(let termination):
                subscribers.removeValue(forKey: subscriberID)
                return termination.result()
            }
        }

        mutating func cancelSubscriber(_ subscriberID: Int) -> EventWaiter<Element>? {
            guard let subscriber = subscribers.removeValue(forKey: subscriberID) else {
                return nil
            }

            if case .waiting(let waiter, _) = subscriber.state {
                return waiter
            }

            return nil
        }

        private func publish(
            _ element: Element,
            for subscriber: inout Subscriber,
            context: PublishContext,
            deliveries: inout [Delivery]
        ) {
            switch subscriber.state {
            case .open(var buffer, var drops):
                let didTerminate = appendBuffered(
                    element: element,
                    into: &buffer,
                    drops: &drops,
                    context: context
                )
                subscriber.state =
                    if didTerminate {
                        .terminal(.failed(context.overflowError))
                    } else {
                        .open(buffer: buffer, drops: drops)
                    }
            case .waiting(let waiter, var drops):
                if let notice = drops.takeNotice(
                    overflowStrategy: context.overflowStrategy
                ) {
                    subscriber.state = .open(buffer: [element], drops: drops)
                    deliveries.append((waiter, .success(notice)))
                } else {
                    subscriber.state = .open(buffer: [], drops: drops)
                    deliveries.append((waiter, .success(element)))
                }
            case .terminal:
                return
            }
        }

        private func appendBuffered(
            element: Element,
            into buffer: inout [Element],
            drops: inout DropLedger<Element>,
            context: PublishContext
        ) -> Bool {
            if buffer.count < context.capacity {
                buffer.append(element)
                return false
            }

            switch context.overflowStrategy {
            case .failFast:
                buffer.removeAll()
                drops = .none
                return true
            case .dropOldest:
                buffer.removeFirst()
                buffer.append(element)
                drops.recordDrop()
                return false
            }
        }
    }

    private let streamName: String
    private let capacity: Int
    private let overflowStrategy: OverflowStrategy<Element>
    private let state = Mutex(BrokerState())

    init(
        streamName eventStreamName: String,
        capacity eventCapacity: Int,
        overflowStrategy eventOverflowStrategy: OverflowStrategy<Element> = .failFast
    ) {
        streamName = eventStreamName
        capacity = eventCapacity
        overflowStrategy = eventOverflowStrategy
    }

    func subscribe() -> InternalEventSubscription<Element> {
        let subscriberID = state.withLock { $0.subscribe() }
        return InternalEventSubscription(EventSubscription(broker: self, id: subscriberID))
    }

    func publish(_ element: Element) {
        let deliveries = state.withLock { brokerState in
            brokerState.publish(
                element,
                streamName: streamName,
                capacity: capacity,
                overflowStrategy: overflowStrategy
            )
        }
        resume(deliveries)
    }

    var isTerminal: Bool {
        state.withLock { $0.lifecycle.isTerminal }
    }

    func finish(throwing error: WaylandDisplayError? = nil) {
        let deliveries = state.withLock { $0.finish(throwing: error) }
        resume(deliveries)
    }

    func enqueueOrResumeNext(
        subscriberID: Int,
        continuation: EventWaiter<Element>
    ) {
        let immediate = state.withLock { brokerState in
            brokerState.enqueueOrResumeNext(
                subscriberID: subscriberID,
                continuation: continuation,
                overflowStrategy: overflowStrategy
            )
        }

        if let immediate {
            continuation.resume(returning: immediate)
        }
    }

    func cancelSubscriber(_ subscriberID: Int) {
        let waiter = state.withLock { $0.cancelSubscriber(subscriberID) }
        waiter?.resume(returning: .success(nil))
    }

    private func resume(_ deliveries: [Delivery]) {
        for (waiter, result) in deliveries {
            waiter.resume(returning: result)
        }
    }
}
