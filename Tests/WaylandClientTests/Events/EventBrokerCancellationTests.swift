import Foundation
import Synchronization
import Testing

@testable import WaylandClient

@Suite(.timeLimit(.minutes(2)))
struct EventBrokerCancellationTests {
    @Test
    func cancellingPendingNextLeavesSubscriptionOpen() async throws {
        let broker = TypedEventBroker<DisplayEvent>(
            stream: .displayEvents,
            capacity: 4
        )
        let subscription = broker.subscribe()

        try await withThrowingTaskGroup(of: DisplayEvent?.self) { group in
            group.addTask {
                var iterator = subscription.makeAsyncIterator()
                return try await iterator.next()
            }

            try await waitUntil { broker.waitingSubscriberCountForTesting() == 1 }
            group.cancelAll()
            guard let event = try await group.next() else {
                Issue.record("Expected cancellation child task result.")
                return
            }
            #expect(event == nil)
        }

        broker.publish(.windowClosed(WindowID(rawValue: 10)))
        var nextIterator = subscription.makeAsyncIterator()
        do {
            let event = try await nextIterator.next()
            #expect(event == .windowClosed(WindowID(rawValue: 10)))
        } catch {
            Issue.record("Expected subscription to remain open, got \(error)")
        }
    }

    @Test
    func cancellingClaimedNextDoesNotCloseSubscription() async throws {
        let broker = TypedEventBroker<DisplayEvent>(
            stream: .displayEvents,
            capacity: 4
        )
        let subscription = broker.subscribe()

        for value in 0..<100 {
            try await withThrowingTaskGroup(of: DisplayEvent?.self) { group in
                group.addTask {
                    var iterator = subscription.makeAsyncIterator()
                    return try await iterator.next()
                }

                try await waitUntil { broker.waitingSubscriberCountForTesting() == 1 }
                broker.publish(.windowClosed(WindowID(rawValue: UInt64(value))))
                group.cancelAll()
                _ = try await group.next()
            }
        }

        broker.publish(.windowClosed(WindowID(rawValue: 999)))
        var iterator = subscription.makeAsyncIterator()
        do {
            let event = try await iterator.next()
            #expect(event == .windowClosed(WindowID(rawValue: 999)))
        } catch {
            Issue.record("Expected subscription to receive later event, got \(error)")
        }
    }

    @Test
    func cancellingAfterPublishClaimsWaitingNextDeliversClaimedEvent() async throws {
        let broker = TypedEventBroker<DisplayEvent>(
            stream: .displayEvents,
            capacity: 4
        )
        let subscription = broker.subscribe()
        let event = DisplayEvent.windowClosed(WindowID(rawValue: 12))

        try await withThrowingTaskGroup(of: DisplayEvent?.self) { group in
            group.addTask {
                var iterator = subscription.makeAsyncIterator()
                return try await iterator.next()
            }

            try await waitUntil { broker.waitingSubscriberCountForTesting() == 1 }
            let deliveries = broker.claimPublishDeliveriesForTesting(event)
            group.cancelAll()
            broker.resumeDeliveriesForTesting(deliveries)

            guard let delivered = try await group.next() else {
                Issue.record("Expected claimed delivery task result.")
                return
            }
            #expect(delivered == event)
        }
    }

    @Test
    func cancellingAfterBufferedEventIsClaimedDeliversClaimedEvent() async throws {
        let broker = TypedEventBroker<DisplayEvent>(
            stream: .displayEvents,
            capacity: 4
        )
        let subscription = broker.subscribe()
        let event = DisplayEvent.windowClosed(WindowID(rawValue: 13))
        let gate = ResumeGate()

        broker.publish(event)

        try await withThrowingTaskGroup(of: DisplayEvent?.self) { group in
            group.addTask {
                try await subscription.nextForTesting {
                    gate.blockUntilReleased()
                }
            }

            try gate.waitUntilBlocked()
            group.cancelAll()
            gate.release()

            guard let delivered = try await group.next() else {
                Issue.record("Expected buffered delivery task result.")
                return
            }
            #expect(delivered == event)
        }
    }

    @Test
    func cancellingAfterFinishClaimsWaitingNextDeliversClaimedError() async throws {
        let broker = TypedEventBroker<DisplayEvent>(
            stream: .displayEvents,
            capacity: 4
        )
        let subscription = broker.subscribe()
        let expected = WaylandDisplayError.internalInvariantViolation(
            .message("finish claimed")
        )

        try await withThrowingTaskGroup(
            of: Result<DisplayEvent?, WaylandDisplayError>.self
        ) { group in
            group.addTask {
                var iterator = subscription.makeAsyncIterator()
                do {
                    return .success(try await iterator.next())
                } catch let error as WaylandDisplayError {
                    return .failure(error)
                } catch {
                    Issue.record("Expected WaylandDisplayError, got \(error)")
                    return .success(nil)
                }
            }

            try await waitUntil { broker.waitingSubscriberCountForTesting() == 1 }
            let deliveries = broker.claimFinishDeliveriesForTesting(throwing: expected)
            group.cancelAll()
            broker.resumeDeliveriesForTesting(deliveries)

            guard let result = try await group.next() else {
                Issue.record("Expected claimed finish task result.")
                return
            }
            #expect(result == .failure(expected))
        }
    }

    @Test
    func finishResumesAllWaitingSubscribers() async throws {
        let broker = TypedEventBroker<DisplayEvent>(
            stream: .displayEvents,
            capacity: 4
        )
        let firstSubscription = broker.subscribe()
        let secondSubscription = broker.subscribe()
        let expected = WaylandDisplayError.internalInvariantViolation(
            .message("finish all")
        )

        try await withThrowingTaskGroup(
            of: Result<DisplayEvent?, WaylandDisplayError>.self
        ) { group in
            group.addTask {
                try await nextResult(from: firstSubscription)
            }
            group.addTask {
                try await nextResult(from: secondSubscription)
            }

            try await waitUntil { broker.waitingSubscriberCountForTesting() == 2 }
            broker.finish(throwing: expected)

            let first = try await #require(group.next())
            let second = try await #require(group.next())
            #expect([first, second] == [.failure(expected), .failure(expected)])
        }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<1_000 {
            if condition() {
                return
            }

            try await Task.sleep(for: .milliseconds(1))
        }

        Issue.record("Timed out waiting for condition.")
    }
}

private func nextResult(
    from subscription: InternalEventSubscription<DisplayEvent>
) async throws -> Result<DisplayEvent?, WaylandDisplayError> {
    var iterator = subscription.makeAsyncIterator()
    do {
        return .success(try await iterator.next())
    } catch {
        return .failure(error)
    }
}

// SAFETY: Gate state is private and every access is protected by NSCondition.
private final class ResumeGate: @unchecked Sendable {
    private struct State {
        var isBlocked = false
        var isReleased = false
    }

    private let condition = NSCondition()
    private var state = State()

    func blockUntilReleased() {
        condition.lock()
        state.isBlocked = true
        condition.broadcast()
        while !state.isReleased {
            condition.wait()
        }
        condition.unlock()
    }

    func release() {
        condition.lock()
        state.isReleased = true
        condition.broadcast()
        condition.unlock()
    }

    func waitUntilBlocked() throws {
        condition.lock()
        defer { condition.unlock() }
        guard !state.isBlocked else {
            return
        }

        let deadline = Date().addingTimeInterval(60)
        while !state.isBlocked {
            guard condition.wait(until: deadline) else {
                Issue.record("Timed out waiting for resume gate.")
                return
            }
        }
    }
}
