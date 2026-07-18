#if ENABLE_TESTING

    import Testing

    @testable import WaylandRuntime

    @Suite(.timeLimit(.minutes(1)))
    struct CompletionCellTests {
        @Test
        func completionResumesManyPendingWaiters() async throws {
            let cell = CompletionCell<Int>()
            let waiterCount = 32
            let waiters = (0..<waiterCount).map { _ in
                // swiftlint:disable:next no_unstructured_task
                Task { await cell.wait() }
            }
            defer { cell.complete(-1) }

            try await waitUntil { cell.pendingWaiterCountForTesting == waiterCount }

            #expect(cell.complete(42))
            for waiter in waiters {
                #expect(await waiter.value == 42)
            }
        }

        @Test
        func waitersArrivingAfterCompletionReceiveCachedValue() async throws {
            let cell = CompletionCell<String>()
            // swiftlint:disable:next no_unstructured_task
            let pendingWaiter = Task { await cell.wait() }
            defer { cell.complete("cleanup") }

            try await waitUntil { cell.pendingWaiterCountForTesting == 1 }
            #expect(cell.complete("ready"))

            #expect(await pendingWaiter.value == "ready")
            #expect(await cell.wait() == "ready")
            #expect(await cell.wait() == "ready")
        }

        @Test
        func firstCompletionWins() async {
            let cell = CompletionCell<Int>()

            #expect(cell.complete(1))
            #expect(!cell.complete(2))
            #expect(await cell.wait() == 1)
        }

        @Test
        func initiallyCompletedCellReturnsItsValue() async {
            let cell = CompletionCell(completed: "ready")

            #expect(await cell.wait() == "ready")
            #expect(!cell.complete("replacement"))
        }

        @Test
        func cancellationDoesNotEndPendingWait() async throws {
            let cell = CompletionCell<Int>()
            // swiftlint:disable:next no_unstructured_task
            let waiter = Task { await cell.wait() }
            defer { cell.complete(-1) }

            try await waitUntil { cell.pendingWaiterCountForTesting == 1 }
            waiter.cancel()
            await Task.yield()

            #expect(cell.pendingWaiterCountForTesting == 1)
            #expect(cell.complete(7))
            #expect(await waiter.value == 7)
        }

        private func waitUntil(_ condition: () -> Bool) async throws {
            for _ in 0..<1_000 {
                if condition() {
                    return
                }
                try await Task.sleep(for: .milliseconds(1))
            }

            throw CompletionCellTestError.timedOut
        }
    }

    private enum CompletionCellTestError: Error {
        case timedOut
    }

#endif
