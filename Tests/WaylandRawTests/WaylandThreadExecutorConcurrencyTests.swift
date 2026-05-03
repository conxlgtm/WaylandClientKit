import Glibc
import Synchronization
import Testing

@testable import WaylandRawUnsafeShim

private actor ShutdownCompletionRecorder {
    private var completions: [String] = []

    var values: [String] {
        completions
    }

    func append(_ value: String) {
        completions.append(value)
    }
}

private final class ConcurrentShutdownGate: Sendable {
    private struct State: Sendable {
        var didEnter = false
        var isOpen = false
    }

    private let state = Mutex(State())

    func enterAndWaitUntilOpened() {
        state.withLock { $0.didEnter = true }

        while !state.withLock({ $0.isOpen }) {
            usleep(1_000)
        }
    }

    func waitUntilEntered() -> Bool {
        waitUntil {
            state.withLock { $0.didEnter }
        }
    }

    func open() {
        state.withLock { $0.isOpen = true }
    }
}

private func waitUntil(_ predicate: () -> Bool) -> Bool {
    for _ in 0..<1_000 {
        if predicate() {
            return true
        }

        usleep(1_000)
    }

    return false
}

@Suite
struct WaylandThreadExecutorConcurrencyTests {
    @Test
    func concurrentShutdownCallerWaitsForFirstJoiner() async throws {
        let executor = try WaylandThreadExecutor()
        let gate = ConcurrentShutdownGate()
        let completions = ShutdownCompletionRecorder()
        defer {
            gate.open()
            executor.shutdown(.abandonWaylandSources)
        }

        try executor.enqueueOperationForTesting {
            gate.enterAndWaitUntilOpened()
        }
        #expect(gate.waitUntilEntered())

        async let first: Void = {
            executor.shutdown(.abandonWaylandSources)
            await completions.append("first")
        }()

        #expect(
            waitUntil {
                executor.lifecycleSnapshotForTesting.state
                    == .joining(.abandonWaylandSources)
            }
        )

        async let second: Void = {
            executor.shutdown(.orderly)
            await completions.append("second")
        }()

        usleep(10_000)
        #expect(await completions.values.isEmpty)

        gate.open()
        _ = await (first, second)
        let stopped = executor.lifecycleSnapshotForTesting
        let completionSet = Set(await completions.values)

        #expect(stopped.state == .joined(.abandonWaylandSources))
        #expect(stopped.hasJoinedThread)
        #expect(completionSet == ["first", "second"])
    }
}
