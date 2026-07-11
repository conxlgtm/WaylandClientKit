import Testing

@testable import WaylandClient

@Suite(.timeLimit(.minutes(1)))
struct EventSequenceIterationTests {
    @Test
    func copiedSequenceCreatesIndependentIterators() async throws {
        let broker = makeBroker()
        let events = DisplayEvents(InternalEventSubscriptionFactory(broker))
        let copiedEvents = events
        var first = events.makeAsyncIterator()
        var second = copiedEvents.makeAsyncIterator()
        let event = DisplayEvent.windowClosed(WindowID(rawValue: 42))

        broker.publish(event)

        #expect(try await first.next() == event)
        #expect(try await second.next() == event)
    }

    @Test
    func concurrentIteratorsReceiveIndependentDelivery() async throws {
        let broker = makeBroker()
        let events = DisplayEvents(InternalEventSubscriptionFactory(broker))
        let event = DisplayEvent.windowClosed(WindowID(rawValue: 43))

        try await withThrowingTaskGroup(of: DisplayEvent?.self) { group in
            group.addTask { try await next(from: events) }
            group.addTask { try await next(from: events) }
            try await waitForSubscriberCount(2, broker: broker)

            broker.publish(event)

            #expect(try await group.next() == event)
            #expect(try await group.next() == event)
        }
    }

    @Test
    func cancellingOneIteratorDoesNotAffectAnother() async throws {
        let broker = makeBroker()
        let events = DisplayEvents(InternalEventSubscriptionFactory(broker))
        try await withThrowingTaskGroup(of: DisplayEvent?.self) { group in
            group.addTask { try await next(from: events) }
            try await waitForSubscriberCount(1, broker: broker)
            group.cancelAll()
            _ = try await group.next()
        }

        let event = DisplayEvent.windowClosed(WindowID(rawValue: 44))
        var remaining = events.makeAsyncIterator()
        broker.publish(event)

        #expect(try await remaining.next() == event)
    }

    private func makeBroker() -> TypedEventBroker<DisplayEvent> {
        TypedEventBroker(stream: .displayEvents, capacity: 4)
    }

    private func next(from events: DisplayEvents) async throws -> DisplayEvent? {
        var iterator = events.makeAsyncIterator()
        return try await iterator.next()
    }

    private func waitForSubscriberCount(
        _ expectedCount: Int,
        broker: TypedEventBroker<DisplayEvent>
    ) async throws {
        for _ in 0..<1_000 {
            if broker.waitingSubscriberCountForTesting() == expectedCount {
                return
            }
            try await Task.sleep(for: .milliseconds(1))
        }

        Issue.record("Timed out waiting for \(expectedCount) event subscribers")
    }
}
