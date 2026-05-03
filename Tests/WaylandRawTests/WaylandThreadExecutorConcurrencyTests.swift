import Dispatch
import Glibc
import Synchronization
import Testing

@testable import WaylandRawUnsafeShim

private final class ShutdownCompletionRecorder: Sendable {
    private struct State: Sendable {
        var starts = Set<String>()
        var completions = Set<String>()
    }

    private let state = Mutex(State())

    var startedValues: Set<String> {
        state.withLock { $0.starts }
    }

    var values: Set<String> {
        state.withLock { $0.completions }
    }

    func appendStarted(_ value: String) {
        state.withLock { state in
            _ = state.starts.insert(value)
        }
    }

    func append(_ value: String) {
        state.withLock { state in
            _ = state.completions.insert(value)
        }
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

private func enqueueShutdownCaller(
    executor: WaylandThreadExecutor,
    mode: ShutdownMode,
    label: String,
    recorder: ShutdownCompletionRecorder,
    group: DispatchGroup
) {
    group.enter()
    // This test intentionally uses blocking threads: shutdown() waits for owner-thread exit.
    // Running those calls as Swift tasks can starve the test body that opens the gate.
    // swiftlint:disable:next no_dispatch_queue
    DispatchQueue.global(qos: .userInitiated).async {
        recorder.appendStarted(label)
        executor.shutdown(mode)
        recorder.append(label)
        group.leave()
    }
}

@Suite
struct WaylandThreadExecutorConcurrencyTests {
    @Test
    func concurrentShutdownCallerWaitsForFirstJoiner() throws {
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

        let group = DispatchGroup()
        enqueueShutdownCaller(
            executor: executor,
            mode: .orderly,
            label: "first",
            recorder: completions,
            group: group
        )
        enqueueShutdownCaller(
            executor: executor,
            mode: .orderly,
            label: "second",
            recorder: completions,
            group: group
        )

        #expect(
            waitUntil {
                completions.startedValues == ["first", "second"]
            }
        )
        usleep(10_000)
        #expect(completions.values.isEmpty)

        gate.open()
        #expect(group.wait(timeout: .now() + .seconds(5)) == .success)
        let stopped = executor.lifecycleSnapshotForTesting

        #expect(stopped.state == .joined(.abandonWaylandSources))
        #expect(stopped.hasJoinedThread)
        #expect(completions.values == ["first", "second"])
    }

    @Test
    func manyConcurrentShutdownCallersWaitForSingleJoiner() throws {
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

        let group = DispatchGroup()
        for label in ["first"] + lateCallerLabels {
            enqueueShutdownCaller(
                executor: executor,
                mode: .orderly,
                label: label,
                recorder: completions,
                group: group
            )
        }

        #expect(
            waitUntil {
                completions.startedValues == Set(["first"] + lateCallerLabels)
            }
        )
        usleep(10_000)
        #expect(completions.values.isEmpty)

        gate.open()
        #expect(group.wait(timeout: .now() + .seconds(5)) == .success)
        let stopped = executor.lifecycleSnapshotForTesting

        #expect(stopped.state == .joined(.abandonWaylandSources))
        #expect(stopped.hasJoinedThread)
        #expect(completions.values == Set(["first"] + lateCallerLabels))
    }
}
