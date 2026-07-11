import WaylandRuntime

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
        isolation _: isolated (any Actor)?,
        beforeImmediateResumeForTesting: (() -> Void)? = nil
    ) async throws(WaylandDisplayError) -> Element? {
        let waiter = broker.makeWaiter()
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                broker.enqueueOrResumeNext(
                    subscriberID: id,
                    waiter: waiter,
                    continuation: continuation,
                    beforeImmediateResumeForTesting: beforeImmediateResumeForTesting
                )
            }
        } onCancel: {
            broker.cancelWaiter(
                subscriberID: id,
                waiter: waiter
            )
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

// swiftlint:disable type_body_length
@safe
final class TypedEventBroker<Element: Sendable>: Sendable {
    private typealias Waiter = EventWaiterBox<Element>
    private typealias Delivery = EventBrokerDelivery<Element>

    private enum SubscriberState {
        case open(buffer: FIFOQueue<Element>, drops: DropLedger<Element>)
        case waiting(Waiter, drops: DropLedger<Element>)
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
        var nextWaiterID: UInt64 = 1
        var subscribers: [Int: Subscriber] = [:]
        var lifecycle = BrokerLifecycle.open

        mutating func subscribe() -> Int {
            defer { nextID += 1 }
            subscribers[nextID] = Subscriber()
            return nextID
        }

        mutating func makeWaiter() -> Waiter {
            defer { nextWaiterID += 1 }
            return Waiter(id: EventWaiterID(rawValue: nextWaiterID))
        }

        mutating func publish(
            _ element: Element,
            stream: EventStreamIdentity,
            capacity: Int,
            overflowStrategy: OverflowStrategy<Element>
        ) -> [Delivery] {
            guard case .open = lifecycle else { return [] }

            let context = PublishContext(
                capacity: capacity,
                overflowError: WaylandDisplayError.eventSubscriberOverflow(
                    stream: stream,
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
            for subscriberID in subscribers.keys.sorted() {
                guard let subscriber = subscribers[subscriberID] else { continue }
                if case .waiting(let waiter, _) = subscriber.state {
                    subscribers.removeValue(forKey: subscriberID)
                    deliveries.append(
                        EventBrokerDelivery(waiter: waiter, result: termination.result())
                    )
                }
            }

            return deliveries
        }

        mutating func enqueueOrResumeNext(
            subscriberID: Int,
            waiter: Waiter,
            continuation: EventWaiter<Element>,
            overflowStrategy: OverflowStrategy<Element>
        ) -> Result<Element?, WaylandDisplayError>? {
            guard var subscriber = subscribers[subscriberID] else {
                return .success(nil)
            }

            switch subscriber.state {
            case .open(var buffer, var drops):
                if let cancellation = waiter.install(continuation) {
                    subscribers[subscriberID] = subscriber
                    return cancellation
                }

                if !buffer.isEmpty {
                    let element = buffer.popFirst()
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

                subscriber.state = .waiting(waiter, drops: drops)
                subscribers[subscriberID] = subscriber
                return nil
            case .waiting:
                if let cancellation = waiter.install(continuation) {
                    return cancellation
                }
                return .failure(.internalInvariantViolation(.eventSubscriberAwaitedTwice))
            case .terminal(let termination):
                if let cancellation = waiter.install(continuation) {
                    subscribers[subscriberID] = subscriber
                    return cancellation
                }
                subscribers.removeValue(forKey: subscriberID)
                return termination.result()
            }
        }

        mutating func cancelWaiter(subscriberID: Int, waiterID: EventWaiterID) -> Waiter? {
            guard var subscriber = subscribers[subscriberID] else {
                return nil
            }

            guard case .waiting(let waiter, let drops) = subscriber.state else {
                return nil
            }
            guard waiter.id == waiterID else {
                return nil
            }

            subscriber.state = .open(buffer: [], drops: drops)
            subscribers[subscriberID] = subscriber
            return waiter
        }

        mutating func cancelSubscriber(_ subscriberID: Int) -> Waiter? {
            guard let subscriber = subscribers.removeValue(forKey: subscriberID) else {
                return nil
            }

            if case .waiting(let waiter, _) = subscriber.state {
                return waiter
            }

            return nil
        }

        var waitingSubscriberCount: Int {
            subscribers.values.reduce(0) { count, subscriber in
                if case .waiting = subscriber.state {
                    return count + 1
                }

                return count
            }
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
                    deliveries.append(
                        EventBrokerDelivery(waiter: waiter, result: .success(notice))
                    )
                } else {
                    subscriber.state = .open(buffer: [], drops: drops)
                    deliveries.append(
                        EventBrokerDelivery(waiter: waiter, result: .success(element))
                    )
                }
            case .terminal:
                return
            }
        }

        private func appendBuffered(
            element: Element,
            into buffer: inout FIFOQueue<Element>,
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
                _ = buffer.popFirst()
                buffer.append(element)
                drops.recordDrop()
                return false
            }
        }
    }

    private let stream: EventStreamIdentity
    private let capacity: Int
    private let overflowStrategy: OverflowStrategy<Element>
    private let state = EventBrokerLockedState(BrokerState())

    init(
        stream eventStream: EventStreamIdentity,
        capacity eventCapacity: Int,
        overflowStrategy eventOverflowStrategy: OverflowStrategy<Element> = .failFast
    ) {
        stream = eventStream
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
                stream: stream,
                capacity: capacity,
                overflowStrategy: overflowStrategy
            )
        }
        resume(deliveries)
    }

    func makeWaiter() -> EventWaiterBox<Element> {
        state.withLock { $0.makeWaiter() }
    }

    var isTerminal: Bool {
        state.withLock { $0.lifecycle.isTerminal }
    }

    func finish(throwing error: WaylandDisplayError? = nil) {
        let deliveries = state.withLock { $0.finish(throwing: error) }
        resume(deliveries)
    }

    package func claimPublishDeliveriesForTesting(
        _ element: Element
    ) -> EventBrokerPendingDeliveries<Element> {
        let deliveries = state.withLock { brokerState in
            brokerState.publish(
                element,
                stream: stream,
                capacity: capacity,
                overflowStrategy: overflowStrategy
            )
        }
        return EventBrokerPendingDeliveries(deliveries: deliveries)
    }

    package func claimFinishDeliveriesForTesting(
        throwing error: WaylandDisplayError? = nil
    ) -> EventBrokerPendingDeliveries<Element> {
        EventBrokerPendingDeliveries(
            deliveries: state.withLock { $0.finish(throwing: error) }
        )
    }

    package func resumeDeliveriesForTesting(
        _ pendingDeliveries: EventBrokerPendingDeliveries<Element>
    ) {
        resume(pendingDeliveries.deliveries)
    }

    func enqueueOrResumeNext(
        subscriberID: Int,
        waiter: EventWaiterBox<Element>,
        continuation: EventWaiter<Element>,
        beforeImmediateResumeForTesting: (() -> Void)? = nil
    ) {
        let immediate = state.withLock { brokerState in
            brokerState.enqueueOrResumeNext(
                subscriberID: subscriberID,
                waiter: waiter,
                continuation: continuation,
                overflowStrategy: overflowStrategy
            )
        }

        if let immediate {
            beforeImmediateResumeForTesting?()
            waiter.resume()?.resume(returning: immediate)
        }
    }

    func cancelWaiter(subscriberID: Int, waiter: EventWaiterBox<Element>) {
        let cancelledWaiter = state.withLock { brokerState in
            brokerState.cancelWaiter(subscriberID: subscriberID, waiterID: waiter.id)
        }
        guard let cancelledWaiter else {
            waiter.cancelIfPending()
            return
        }

        cancelledWaiter.cancel()?.resume(returning: .success(nil))
    }

    func cancelSubscriber(_ subscriberID: Int) {
        let waiter = state.withLock { $0.cancelSubscriber(subscriberID) }
        waiter?.cancel()?.resume(returning: .success(nil))
    }

    func waitingSubscriberCountForTesting() -> Int {
        state.withLock { $0.waitingSubscriberCount }
    }

    private func resume(_ deliveries: [Delivery]) {
        for delivery in deliveries {
            delivery.waiter.resume()?.resume(returning: delivery.result)
        }
    }
}
// swiftlint:enable type_body_length

struct EventBrokerDelivery<Element: Sendable>: Sendable {
    let waiter: EventWaiterBox<Element>
    let result: Result<Element?, WaylandDisplayError>
}

package struct EventBrokerPendingDeliveries<Element: Sendable>: Sendable {
    let deliveries: [EventBrokerDelivery<Element>]
}
