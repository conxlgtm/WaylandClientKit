import Glibc
import Synchronization
import Testing

@testable import WaylandRawUnsafeShim

private final class ShutdownCompletionRecorder: Sendable {
    private struct State: Sendable {
        var starts: [String] = []
        var completions: [String] = []
    }

    private let state = Mutex(State())

    var startedValues: Set<String> {
        state.withLock { Set($0.starts) }
    }

    var values: Set<String> {
        state.withLock { Set($0.completions) }
    }

    var completionCount: Int {
        state.withLock { $0.completions.count }
    }

    func startCount(for value: String) -> Int {
        state.withLock { state in
            state.starts.count { $0 == value }
        }
    }

    func completionCount(for value: String) -> Int {
        state.withLock { state in
            state.completions.count { $0 == value }
        }
    }

    func appendStarted(_ value: String) {
        state.withLock { state in
            state.starts.append(value)
        }
    }

    func append(_ value: String) {
        state.withLock { state in
            state.completions.append(value)
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
    for _ in 0..<10_000 {
        if predicate() {
            return true
        }

        usleep(1_000)
    }

    return false
}

private final class ShutdownCallerThread {
    private let executor: WaylandThreadExecutor
    private let mode: ShutdownMode
    private let label: String
    private let recorder: ShutdownCompletionRecorder

    init(
        executor newExecutor: WaylandThreadExecutor,
        mode shutdownMode: ShutdownMode,
        label callerLabel: String,
        recorder completionRecorder: ShutdownCompletionRecorder
    ) {
        executor = newExecutor
        mode = shutdownMode
        label = callerLabel
        recorder = completionRecorder
    }

    func start() {
        var attributes = pthread_attr_t()
        let attributeInitResult = pthread_attr_init(&attributes)
        precondition(attributeInitResult == 0, "pthread_attr_init failed")
        let detachResult = pthread_attr_setdetachstate(
            &attributes,
            Int32(PTHREAD_CREATE_DETACHED)
        )
        precondition(detachResult == 0, "pthread_attr_setdetachstate failed")

        let retainedSelf = Unmanaged.passRetained(self).toOpaque()
        var thread = pthread_t()
        let createResult = pthread_create(
            &thread,
            &attributes,
            { pointer in
                guard let pointer else { return nil }

                let caller = Unmanaged<ShutdownCallerThread>
                    .fromOpaque(pointer)
                    .takeRetainedValue()
                caller.run()
                return nil
            },
            retainedSelf
        )
        pthread_attr_destroy(&attributes)

        guard createResult == 0 else {
            Unmanaged<ShutdownCallerThread>.fromOpaque(retainedSelf).release()
            preconditionFailure("pthread_create failed with \(createResult)")
        }
    }

    private func run() {
        recorder.appendStarted(label)
        executor.shutdown(mode)
        recorder.append(label)
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

        ShutdownCallerThread(
            executor: executor,
            mode: .orderly,
            label: "first",
            recorder: completions
        ).start()
        ShutdownCallerThread(
            executor: executor,
            mode: .orderly,
            label: "second",
            recorder: completions
        ).start()

        #expect(
            waitUntil {
                completions.startedValues == ["first", "second"]
            }
        )
        #expect(
            waitUntil {
                executor.lifecycleSnapshotForTesting.state
                    == .joining(.abandonWaylandSources)
            }
        )
        #expect(completions.values.isEmpty)
        #expect(completions.completionCount == 0)

        gate.open()
        #expect(
            waitUntil {
                completions.values == ["first", "second"]
            }
        )
        let stopped = executor.lifecycleSnapshotForTesting

        #expect(stopped.state == .joined(.abandonWaylandSources))
        #expect(stopped.hasJoinedThread)
        #expect(completions.values == ["first", "second"])
        for label in ["first", "second"] {
            #expect(completions.startCount(for: label) == 1)
            #expect(completions.completionCount(for: label) == 1)
        }
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

        for label in ["first"] + lateCallerLabels {
            ShutdownCallerThread(
                executor: executor,
                mode: .orderly,
                label: label,
                recorder: completions
            ).start()
        }

        #expect(
            waitUntil {
                completions.startedValues == Set(["first"] + lateCallerLabels)
            }
        )
        #expect(
            waitUntil {
                executor.lifecycleSnapshotForTesting.state
                    == .joining(.abandonWaylandSources)
            }
        )
        #expect(completions.values.isEmpty)
        #expect(completions.completionCount == 0)

        gate.open()
        #expect(
            waitUntil {
                completions.values == Set(["first"] + lateCallerLabels)
            }
        )
        let stopped = executor.lifecycleSnapshotForTesting

        #expect(stopped.state == .joined(.abandonWaylandSources))
        #expect(stopped.hasJoinedThread)
        #expect(completions.values == Set(["first"] + lateCallerLabels))
        for label in ["first"] + lateCallerLabels {
            #expect(completions.startCount(for: label) == 1)
            #expect(completions.completionCount(for: label) == 1)
        }
    }
}
