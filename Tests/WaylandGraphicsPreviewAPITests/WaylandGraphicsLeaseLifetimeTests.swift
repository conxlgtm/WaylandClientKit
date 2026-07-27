import Testing
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsLeaseLifetimeTests {
    @Test(.timeLimit(.minutes(1)))
    func abandoningFrameLeaseAllowsNextFrame() async throws {
        let storage = try leaseLifetimeStorage()

        do {
            let abandonedLease = try await storage.nextFrame()
            _ = abandonedLease.size
            _ = abandonedLease.contract
            _ = abandonedLease.runtimePath
        }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while clock.now < deadline {
            do {
                let replacementLease = try await storage.nextFrame()
                await replacementLease.cancel()
                await storage.closeForTesting()
                return
            } catch WaylandGraphicsError.frameLeaseActive {
                await Task.yield()
            }
        }

        await storage.closeForTesting()
        Issue.record("abandoned frame lease did not release its backing")
    }

    @Test(.timeLimit(.minutes(1)))
    func backingCloseRacingWithSubmissionEndsClosed() async throws {
        let storage = try leaseLifetimeStorage()
        let lease = try await storage.nextFrame()

        do {
            _ = try await lease.submitForTesting(.clearColor(.black)) {
                await storage.closeForTesting()
            }
            Issue.record("expected backing close to win submission completion")
        } catch WaylandGraphicsError.backingClosed {
            // Expected terminal state.
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        await expectBackingClosed(storage)
    }

    @Test(.timeLimit(.minutes(1)))
    func backingCloseRacingWithCancellationEndsClosed() async throws {
        let storage = try leaseLifetimeStorage()
        let lease = try await storage.nextFrame()

        async let closing: Void = storage.closeForTesting()
        await lease.cancel()
        await closing

        await expectBackingClosed(storage)
    }

    @Test(.timeLimit(.minutes(1)))
    func backingCloseRacingWithAbandonmentEndsClosed() async throws {
        let storage = try leaseLifetimeStorage()

        do {
            let abandonedLease = try await storage.nextFrame()
            _ = abandonedLease.runtimePath
        }
        await storage.closeForTesting()

        await expectBackingClosed(storage)
    }
}

private func leaseLifetimeStorage() throws -> WaylandGraphicsWindowBackingStorage {
    let window = try FakeManagedGraphicsWindow(showDrawFailures: 0)
    return WaylandGraphicsWindowBackingStorage(
        window: window,
        runtimePath: .softwareFallback(
            capabilities: softwareOnlySurfaceCapabilities(),
            reason: .forcedSoftware
        )
    )
}

private func expectBackingClosed(
    _ storage: WaylandGraphicsWindowBackingStorage
) async {
    do {
        let unexpectedLease = try await storage.nextFrame()
        await unexpectedLease.cancel()
        Issue.record("closed backing unexpectedly issued another lease")
    } catch WaylandGraphicsError.backingClosed {
        // Expected terminal state.
    } catch {
        Issue.record("unexpected error: \(error)")
    }
}
