import Testing

@testable import WaylandRaw

@Suite
struct DrawingBufferLeaseTests {
    @Test
    func drawingBufferDeinitReleasesAcquiredBuffer() {
        let pool = TestDrawingBufferPool()
        do {
            guard let drawingBuffer = pool.acquire() else {
                Issue.record("Expected an available drawing buffer.")
                return
            }
            let canWrite = drawingBuffer.canWrite
            #expect(canWrite)
            #expect(pool.state.lifecycle == .acquiredForDrawing)
        }
        #expect(pool.releaseCount == 1)
        #expect(pool.state.lifecycle == .available)
    }
    @Test
    func drawingBufferDiscardReleasesOnce() {
        let pool = TestDrawingBufferPool()
        do {
            guard var drawingBuffer = pool.acquire() else {
                Issue.record("Expected an available drawing buffer.")
                return
            }
            drawingBuffer.discard()
            drawingBuffer.discard()
            let canWrite = drawingBuffer.canWrite
            #expect(!canWrite)
        }
        #expect(pool.releaseCount == 1)
        #expect(pool.state.lifecycle == .available)
    }
    @Test
    func drawingBufferCommitMarksPendingRelease() {
        let pool = TestDrawingBufferPool()
        do {
            guard var drawingBuffer = pool.acquire() else {
                Issue.record("Expected an available drawing buffer.")
                return
            }
            drawingBuffer.markBusy(commitGeneration: 7)
            let canWrite = drawingBuffer.canWrite
            #expect(!canWrite)
            #expect(pool.markedBusyGenerations == [7])
            #expect(pool.state.lifecycle == .pendingRelease(commitGeneration: 7))
        }
        #expect(pool.releaseCount == 0)
        #expect(pool.state.lifecycle == .pendingRelease(commitGeneration: 7))
    }
    @Test
    func drawingBufferRejectsWriteAfterCommit() {
        let pool = TestDrawingBufferPool()
        guard var drawingBuffer = pool.acquire() else {
            Issue.record("Expected an available drawing buffer.")
            return
        }
        let canWriteBeforeCommit = drawingBuffer.canWrite
        #expect(canWriteBeforeCommit)
        drawingBuffer.markBusy(commitGeneration: 8)
        let canWriteAfterCommit = drawingBuffer.canWrite
        #expect(!canWriteAfterCommit)
    }
    @Test
    func poolDoesNotReacquireLiveDrawingBuffer() {
        let pool = TestDrawingBufferPool()
        guard var firstDrawingBuffer = pool.acquire() else {
            Issue.record("Expected the first drawing buffer acquisition to succeed.")
            return
        }
        if var secondDrawingBuffer = pool.acquire() {
            secondDrawingBuffer.discard()
            Issue.record("Expected the live drawing buffer to block reacquisition.")
        }
        firstDrawingBuffer.discard()
        guard var thirdDrawingBuffer = pool.acquire() else {
            Issue.record("Expected discard to make the drawing buffer available again.")
            return
        }
        thirdDrawingBuffer.discard()
        #expect(pool.releaseCount == 2)
        #expect(pool.state.lifecycle == .available)
    }
}

private final class TestDrawingBufferPool {
    private(set) var state = BufferBusyState()
    private(set) var releaseCount = 0
    private(set) var markedBusyGenerations: [UInt64] = []

    func acquire() -> DrawingBufferLease? {
        guard state.acquireForDrawing() else {
            return nil
        }
        return DrawingBufferLease(
            release: { [self] in
                releaseCount += 1
                state.markReleased()
            },
            markPendingRelease: { [self] generation in
                markedBusyGenerations.append(generation)
                return state.markPendingRelease(commitGeneration: generation)
            }
        )
    }
}
