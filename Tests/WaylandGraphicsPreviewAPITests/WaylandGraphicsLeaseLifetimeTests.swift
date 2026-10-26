import Testing
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsLeaseLifetimeTests {
    @Test
    func storedBorrowProjectionsAllowOwnedSnapshotsAfterCancel() async throws {
        let storage = try leaseLifetimeStorage()
        let lease = try await storage.nextFrame()
        let contract = lease.contract
        let explicitSnapshot = ownedContractSnapshot(lease.contract)
        let runtimePath = lease.runtimePath
        let size = lease.size
        let inspectedGeneration = inspectContract(lease.contract)
        #expect(inspectedGeneration == contract.generation)
        await lease.cancel()

        // swiftlint:disable:next no_unstructured_task
        let snapshotTask = Task { contract }
        #expect(await snapshotTask.value == explicitSnapshot)
        #expect(contract.geometry.bufferSize == size)
        #expect(contract.runtimePath == runtimePath)
        await storage.closeForTesting()
    }

    @Test
    func storedBorrowProjectionsAllowOwnedSnapshotsAfterSubmit() async throws {
        let storage = try leaseLifetimeStorage()
        let lease = try await storage.nextFrame()
        let contract = lease.contract
        let result = try await lease.submit(.clearColor(.black))
        #expect(contract.geometry.bufferSize == result.size)
        await storage.closeForTesting()
    }

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

// Swift 6.4 crashes when this Ref scope is inlined into the async test.
@inline(never)
private func inspectContract(
    _ contract: borrowing WaylandGraphicsFrameContract
) -> WaylandGraphicsSurfaceGeneration {
    let reference = Ref(contract)
    return reference.value.generation
}

private func ownedContractSnapshot(
    _ contract: borrowing WaylandGraphicsFrameContract
) -> WaylandGraphicsFrameContract {
    copy contract
}
