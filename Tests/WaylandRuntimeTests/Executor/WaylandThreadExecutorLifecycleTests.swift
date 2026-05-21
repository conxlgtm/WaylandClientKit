#if ENABLE_TESTING
    import Dispatch
    import Glibc
    import Testing

    @testable import WaylandRuntime

    private func waitUntil(_ predicate: () -> Bool) -> Bool {
        for _ in 0..<1_000 {
            if predicate() {
                return true
            }

            usleep(1_000)
        }

        return false
    }

    @Suite(.timeLimit(.minutes(1)))
    struct WaylandThreadExecutorLifecycleTests {
        @Test
        func ownerThreadDeinitDetachesAfterLoopExit() throws {
            var executor: WaylandThreadExecutor? = try WaylandThreadExecutor()
            weak let weakExecutor = executor
            let didRun = DispatchSemaphore(value: 0)

            try executor?.enqueueOperationForTesting { [executor] in
                didRun.signal()
                executor?.requestStopAfterCurrentJob()
            }

            executor = nil

            #expect(didRun.wait(timeout: .now() + .seconds(5)) == .success)
            #expect(
                waitUntil {
                    weakExecutor == nil
                }
            )
        }

        @Test
        func requestStopAfterOwnerDetachDoesNotRewriteShutdownMode() {
            var state = WaylandThreadExecutorState()
            state.phase = .detachedAfterOwnerThreadExit(.orderly)

            _ = state.requestStop(.abandonWaylandSources)

            #expect(state.phase == .detachedAfterOwnerThreadExit(.orderly))
        }

        @Test
        func loopExitAloneCannotDestroySynchronizationPrimitives() {
            #expect(!ExecutorLifecycle.loopExited(.orderly).canDestroySynchronizationPrimitives)
            #expect(
                ExecutorLifecycle.detachedAfterOwnerThreadExit(.orderly)
                    .canDestroySynchronizationPrimitives
            )
            #expect(ExecutorLifecycle.joined(.orderly).canDestroySynchronizationPrimitives)
        }
    }

#endif
