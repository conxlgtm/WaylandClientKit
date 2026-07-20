import Testing

@testable import WaylandClient

@Suite(.timeLimit(.minutes(1)))
struct EventBrokerModelTests {
    @Test(arguments: [BrokerModelOverflow.failFast, .dropOldest])
    func generatedCommandTracesMatchModel(_ overflow: BrokerModelOverflow) async {
        for seed in 1...100 {
            await runTrace(seed: UInt64(seed), overflow: overflow)
        }
    }

    private func runTrace(seed: UInt64, overflow: BrokerModelOverflow) async {
        let capacity = 3
        let finishError = WaylandDisplayError.internalInvariantViolation(
            .message("generated broker finish")
        )
        var trace = BrokerModelTrace(seed: seed, capacity: capacity, overflow: overflow)
        await trace.runCommands(count: 100)

        let terminal: BrokerModelTermination =
            if seed.isMultiple(of: 2) {
                .finished
            } else {
                .failed(finishError)
            }
        await finishAndDrain(
            broker: trace.broker,
            iterators: &trace.iterators,
            model: &trace.model,
            terminal: terminal,
            repeatedFinishError: finishError
        )
    }

    private func finishAndDrain(
        broker: TypedEventBroker<BrokerModelEvent>,
        iterators: inout [InternalEventSubscriptionIterator<BrokerModelEvent>?],
        model: inout [BrokerModelSubscriber?],
        terminal: BrokerModelTermination,
        repeatedFinishError: WaylandDisplayError
    ) async {
        switch terminal {
        case .finished:
            broker.finish()
        case .failed(let error):
            broker.finish(throwing: error)
        }

        for index in model.indices {
            guard var subscriber = model[index], var iterator = iterators[index] else {
                continue
            }
            while !subscriber.isRemoved {
                let expected = subscriber.next(terminal: terminal)
                await expectNext(&iterator, matches: expected)
            }
            iterators[index] = iterator
            model[index] = subscriber
        }

        broker.publish(.value(Int.max))
        broker.finish(throwing: repeatedFinishError)
        for index in iterators.indices {
            guard var iterator = iterators[index] else { continue }
            await expectNext(&iterator, matches: .success(nil))
            iterators[index] = iterator
        }
    }

    private func expectNext(
        _ iterator: inout InternalEventSubscriptionIterator<BrokerModelEvent>,
        matches expected: Result<BrokerModelEvent?, WaylandDisplayError>?
    ) async {
        guard let expected else {
            Issue.record("model attempted a blocking read")
            return
        }

        let actual: Result<BrokerModelEvent?, WaylandDisplayError>
        do {
            actual = .success(try await iterator.next())
        } catch {
            actual = .failure(error)
        }
        #expect(actual == expected)
    }
}

private struct BrokerModelTrace {
    let broker: TypedEventBroker<BrokerModelEvent>
    var iterators: [InternalEventSubscriptionIterator<BrokerModelEvent>?]
    var model: [BrokerModelSubscriber?]

    private let capacity: Int
    private let overflow: BrokerModelOverflow
    private let overflowError: WaylandDisplayError
    private var random: BrokerModelRandom
    private var nextValue = 1

    init(seed: UInt64, capacity: Int, overflow: BrokerModelOverflow) {
        let broker = TypedEventBroker<BrokerModelEvent>(
            stream: .displayEvents,
            capacity: capacity,
            overflowStrategy: overflow.strategy
        )
        self.broker = broker
        iterators = [
            broker.subscribe().makeAsyncIterator(),
            broker.subscribe().makeAsyncIterator(),
            nil,
        ]
        model = [BrokerModelSubscriber(), BrokerModelSubscriber(), nil]
        self.capacity = capacity
        self.overflow = overflow
        overflowError = WaylandDisplayError.eventSubscriberOverflow(
            stream: .displayEvents,
            capacity: capacity
        )
        random = BrokerModelRandom(seed: seed)
    }

    mutating func runCommands(count: Int) async {
        for _ in 0..<count {
            switch random.next() % 8 {
            case 0...4:
                publish()
            case 5:
                await readIfReady()
            case 6:
                cancelSubscription()
            default:
                openSubscriptionIfNeeded()
            }
        }
    }

    private mutating func publish() {
        let event = BrokerModelEvent.value(nextValue)
        nextValue += 1
        broker.publish(event)
        for index in model.indices {
            model[index]?.publish(
                event,
                capacity: capacity,
                overflow: overflow,
                overflowError: overflowError
            )
        }
    }

    private mutating func readIfReady() async {
        let index = nextIndex()
        guard var subscriber = model[index], subscriber.hasImmediateResult,
            var iterator = iterators[index]
        else {
            return
        }

        let expected = subscriber.next(terminal: nil)
        let actual: Result<BrokerModelEvent?, WaylandDisplayError>
        do {
            actual = .success(try await iterator.next())
        } catch {
            actual = .failure(error)
        }
        #expect(actual == expected)
        iterators[index] = iterator
        model[index] = subscriber
    }

    private mutating func cancelSubscription() {
        let index = nextIndex()
        iterators[index] = nil
        model[index] = nil
    }

    private mutating func openSubscriptionIfNeeded() {
        let index = nextIndex()
        guard model[index] == nil else { return }
        iterators[index] = broker.subscribe().makeAsyncIterator()
        model[index] = BrokerModelSubscriber()
    }

    private mutating func nextIndex() -> Int {
        Int(random.next() % UInt64(model.count))
    }
}

enum BrokerModelEvent: Equatable, Sendable {
    case value(Int)
    case dropped(Int)
}

enum BrokerModelOverflow: Sendable {
    case failFast
    case dropOldest

    var strategy: OverflowStrategy<BrokerModelEvent> {
        switch self {
        case .failFast:
            .failFast
        case .dropOldest:
            .dropOldest { .dropped($0) }
        }
    }
}

private enum BrokerModelTermination {
    case finished
    case failed(WaylandDisplayError)

    var result: Result<BrokerModelEvent?, WaylandDisplayError> {
        switch self {
        case .finished:
            .success(nil)
        case .failed(let error):
            .failure(error)
        }
    }
}

private struct BrokerModelSubscriber {
    private var buffer: [BrokerModelEvent] = []
    private var droppedCount = 0
    private var failure: WaylandDisplayError?
    private(set) var isRemoved = false

    var hasImmediateResult: Bool {
        isRemoved || !buffer.isEmpty || droppedCount > 0 || failure != nil
    }

    mutating func publish(
        _ event: BrokerModelEvent,
        capacity: Int,
        overflow: BrokerModelOverflow,
        overflowError: WaylandDisplayError
    ) {
        guard !isRemoved, failure == nil else { return }
        guard buffer.count == capacity else {
            buffer.append(event)
            return
        }

        switch overflow {
        case .failFast:
            buffer.removeAll()
            droppedCount = 0
            failure = overflowError
        case .dropOldest:
            buffer.removeFirst()
            buffer.append(event)
            droppedCount += 1
        }
    }

    mutating func next(
        terminal: BrokerModelTermination?
    ) -> Result<BrokerModelEvent?, WaylandDisplayError>? {
        if isRemoved {
            return .success(nil)
        }
        if !buffer.isEmpty {
            return .success(buffer.removeFirst())
        }
        if droppedCount > 0 {
            defer { droppedCount = 0 }
            return .success(.dropped(droppedCount))
        }
        if let failure {
            isRemoved = true
            return .failure(failure)
        }
        if let terminal {
            isRemoved = true
            return terminal.result
        }
        return nil
    }
}

private struct BrokerModelRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
