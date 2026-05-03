import Glibc
import Synchronization
import Testing

@testable import WaylandRawUnsafeShim

private actor ShutdownCompletionRecorder {
    private var starts: [String] = []
    private var completions: [String] = []

    var startedValues: [String] {
        starts
    }

    var values: [String] {
        completions
    }

    func appendStarted(_ value: String) {
        starts.append(value)
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
    for _ in 0..<5_000 {
        if predicate() {
            return true
        }

        usleep(1_000)
    }

    return false
}

private func waitUntilAsync(_ predicate: () async -> Bool) async -> Bool {
    for _ in 0..<5_000 {
        if await predicate() {
            return true
        }

        do {
            try await Task.sleep(nanoseconds: 1_000_000)
        } catch {
            return false
        }
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

        executor.requestStopAfterCurrentJob(.abandonWaylandSources)
        #expect(
            executor.lifecycleSnapshotForTesting.state
                == .stopRequested(.abandonWaylandSources)
        )

        async let first: Void = {
            await completions.appendStarted("first")
            executor.shutdown(.orderly)
            await completions.append("first")
        }()

        async let second: Void = {
            await completions.appendStarted("second")
            executor.shutdown(.orderly)
            await completions.append("second")
        }()

        #expect(
            await waitUntilAsync {
                Set(await completions.startedValues) == ["first", "second"]
            }
        )
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

    @Test
    func manyConcurrentShutdownCallersWaitForSingleJoiner() async throws {
        let executor = try WaylandThreadExecutor()
        let gate = ConcurrentShutdownGate()
        let completions = ShutdownCompletionRecorder()
        let lateCallerLabels = (0..<6).map { "late-\($0)" }
        defer {
            gate.open()
            executor.shutdown(.abandonWaylandSources)
        }

        try executor.enqueueOperationForTesting {
            gate.enterAndWaitUntilOpened()
        }
        #expect(gate.waitUntilEntered())

        executor.requestStopAfterCurrentJob(.abandonWaylandSources)
        #expect(
            executor.lifecycleSnapshotForTesting.state
                == .stopRequested(.abandonWaylandSources)
        )

        async let first: Void = {
            await completions.appendStarted("first")
            executor.shutdown(.orderly)
            await completions.append("first")
        }()

        async let lateCallers: Void = withTaskGroup(of: Void.self) { group in
            for label in lateCallerLabels {
                group.addTask {
                    await completions.appendStarted(label)
                    executor.shutdown(.orderly)
                    await completions.append(label)
                }
            }
        }

        #expect(
            await waitUntilAsync {
                Set(await completions.startedValues) == Set(["first"] + lateCallerLabels)
            }
        )
        usleep(10_000)
        #expect(await completions.values.isEmpty)

        gate.open()
        _ = await (first, lateCallers)
        let stopped = executor.lifecycleSnapshotForTesting
        let completionSet = Set(await completions.values)

        #expect(stopped.state == .joined(.abandonWaylandSources))
        #expect(stopped.hasJoinedThread)
        #expect(completionSet == Set(["first"] + lateCallerLabels))
    }
}
