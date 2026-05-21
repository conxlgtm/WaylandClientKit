#if ENABLE_TESTING
    import Foundation
    import Glibc
    import Testing

    @testable import WaylandRuntime

    // SAFETY: Mutable recorder state is private and every access is protected by
    // NSCondition, which ThreadSanitizer recognizes for these detached-thread tests.
    private final class ShutdownCompletionRecorder: @unchecked Sendable {
        private struct State: Sendable {
            var starts: [String] = []
            var completions: [String] = []
        }

        private let condition = NSCondition()
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

        func waitUntilStartedValues(_ expectedValues: Set<String>) -> Bool {
            waitUntil { Set($0.starts) == expectedValues }
        }

        func waitUntilValues(_ expectedValues: Set<String>) -> Bool {
            waitUntil { Set($0.completions) == expectedValues }
        }

        private func withState<Result: Sendable>(
            _ body: (inout State) -> Result
        ) -> Result {
            condition.lock()
            let result = body(&state)
            condition.broadcast()
            condition.unlock()
            return result
        }

        private func waitUntil(_ predicate: (State) -> Bool) -> Bool {
            condition.lock()
            defer { condition.unlock() }
            guard !predicate(state) else {
                return true
            }

            let deadline = Date().addingTimeInterval(10)
            while !predicate(state) {
                guard condition.wait(until: deadline) else {
                    return predicate(state)
                }
            }
            return true
        }
    }

    // SAFETY: Gate state is private and every access is protected by NSCondition.
    private final class ConcurrentShutdownGate: @unchecked Sendable {
        private struct State: Sendable {
            var didEnter = false
            var isOpen = false
        }

        private let condition = NSCondition()
        private var state = State()

        func enterAndWaitUntilOpened() {
            condition.lock()
            state.didEnter = true
            condition.broadcast()
            while !state.isOpen {
                condition.wait()
            }
            condition.unlock()
        }

        func waitUntilEntered() -> Bool {
            condition.lock()
            defer { condition.unlock() }
            guard !state.didEnter else {
                return true
            }

            let deadline = Date().addingTimeInterval(10)
            while !state.didEnter {
                guard condition.wait(until: deadline) else {
                    return false
                }
            }
            return true
        }

        func open() {
            condition.lock()
            state.isOpen = true
            condition.broadcast()
            condition.unlock()
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

    @Suite(.timeLimit(.minutes(1)))
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
                completions.waitUntilStartedValues(["first", "second"])
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
                completions.waitUntilValues(["first", "second"])
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
                completions.waitUntilStartedValues(Set(["first"] + lateCallerLabels))
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
                completions.waitUntilValues(Set(["first"] + lateCallerLabels))
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
