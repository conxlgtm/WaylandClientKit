#if ENABLE_TESTING
    import Foundation
    import Glibc
    import Testing

    @testable import WaylandRuntime

    // SAFETY: Mutable recorder state is private and every access is protected by
    // NSLock, which ThreadSanitizer recognizes for these detached-thread tests.
    private final class ShutdownCompletionRecorder: @unchecked Sendable {
        private struct State: Sendable {
            var starts: [String] = []
            var completions: [String] = []
        }

        private let lock = NSLock()
        private var state = State()

        var startedValues: Set<String> {
            withState { Set($0.starts) }
        }

        var values: Set<String> {
            withState { Set($0.completions) }
        }

        var completionCount: Int {
            withState { $0.completions.count }
        }

        func startCount(for value: String) -> Int {
            withState { state in
                state.starts.count { $0 == value }
            }
        }

        func completionCount(for value: String) -> Int {
            withState { state in
                state.completions.count { $0 == value }
            }
        }

        func appendStarted(_ value: String) {
            withState { state in
                state.starts.append(value)
            }
        }

        func append(_ value: String) {
            withState { state in
                state.completions.append(value)
            }
        }

        private func withState<Result: Sendable>(
            _ body: (inout State) -> Result
        ) -> Result {
            lock.lock()
            defer { lock.unlock() }
            return body(&state)
        }
    }

    // SAFETY: Gate state is private and every access is protected by NSLock.
    private final class ConcurrentShutdownGate: @unchecked Sendable {
        private struct State: Sendable {
            var didEnter = false
            var isOpen = false
        }

        private let lock = NSLock()
        private var state = State()

        func enterAndWaitUntilOpened() {
            withState { $0.didEnter = true }

            while !withState({ $0.isOpen }) {
                usleep(1_000)
            }
        }

        func waitUntilEntered() -> Bool {
            waitUntil {
                withState { $0.didEnter }
            }
        }

        func open() {
            withState { $0.isOpen = true }
        }

        private func withState<Result: Sendable>(
            _ body: (inout State) -> Result
        ) -> Result {
            lock.lock()
            defer { lock.unlock() }
            return body(&state)
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

    private func startShutdownCallerThread(
        executor: WaylandThreadExecutor,
        mode: ShutdownMode,
        label: String,
        recorder: ShutdownCompletionRecorder
    ) {
        Thread.detachNewThread {
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

            startShutdownCallerThread(
                executor: executor,
                mode: .orderly,
                label: "first",
                recorder: completions
            )
            startShutdownCallerThread(
                executor: executor,
                mode: .orderly,
                label: "second",
                recorder: completions
            )

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
                startShutdownCallerThread(
                    executor: executor,
                    mode: .orderly,
                    label: label,
                    recorder: completions
                )
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

#endif
