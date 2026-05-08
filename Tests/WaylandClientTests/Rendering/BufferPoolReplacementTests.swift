import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct BufferPoolReplacementTests {
    @Test
    func resizeAllocationFailureDoesNotRetireCurrentPool() {
        let oldPool = FakeBufferPool(size: TopLevelSize(width: 640, height: 480), isBusy: true)
        var activePool: FakeBufferPool? = oldPool
        var retiredPools: [FakeBufferPool] = []

        #expect(throws: FakeBufferPoolError.allocationFailed) {
            _ = try BufferPoolReplacement.pool(
                for: TopLevelSize(width: 800, height: 600),
                active: &activePool,
                retired: &retiredPools
            ) {
                throw FakeBufferPoolError.allocationFailed
            }
        }

        #expect(activePool === oldPool)
        #expect(retiredPools.isEmpty)
        #expect(oldPool.retirementReason == nil)
    }

    @Test
    func retryAfterResizeAllocationFailureInstallsReplacementPool() throws {
        let oldPool = FakeBufferPool(size: TopLevelSize(width: 640, height: 480), isBusy: true)
        let newPool = FakeBufferPool(size: TopLevelSize(width: 800, height: 600), isBusy: false)
        var activePool: FakeBufferPool? = oldPool
        var retiredPools: [FakeBufferPool] = []

        #expect(throws: FakeBufferPoolError.allocationFailed) {
            _ = try BufferPoolReplacement.pool(
                for: newPool.size,
                active: &activePool,
                retired: &retiredPools
            ) {
                throw FakeBufferPoolError.allocationFailed
            }
        }

        let replacement = BufferPoolReplacement.pool(
            for: newPool.size,
            active: &activePool,
            retired: &retiredPools
        ) {
            newPool
        }

        #expect(replacement === newPool)
        #expect(activePool === newPool)
        #expect(retiredPools.count == 1)
        #expect(retiredPools.first === oldPool)
        #expect(oldPool.retirementReason == .resized)
    }
}

private enum FakeBufferPoolError: Error, Equatable {
    case allocationFailed
}

private final class FakeBufferPool: BufferPoolReplacementCandidate {
    let size: TopLevelSize
    let hasBusyBuffers: Bool
    private(set) var retirementReason: BufferRetirementReason?

    init(size poolSize: TopLevelSize, isBusy poolIsBusy: Bool) {
        size = poolSize
        hasBusyBuffers = poolIsBusy
    }

    func retire(reason: BufferRetirementReason) {
        retirementReason = reason
    }
}
