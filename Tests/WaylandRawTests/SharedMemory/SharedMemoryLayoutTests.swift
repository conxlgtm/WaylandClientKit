import Testing

@testable import WaylandRaw

@Suite
struct SharedMemoryLayoutTests {
    @Test
    func bufferLayoutComputesXRGB8888StrideAndBytes() throws {
        let layout = try BufferLayout(width: 640, height: 480)
        #expect(layout.width == 640)
        #expect(layout.height == 480)
        #expect(layout.stride == 2_560)
        #expect(layout.byteCount == 1_228_800)
    }
    @Test
    func bufferLayoutRejectsInvalidDimensions() {
        var didThrow = false
        do {
            _ = try BufferLayout(width: 0, height: 480)
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }
    @Test
    func bufferLayoutRejectsOverflow() {
        var didThrow = false
        do {
            _ = try BufferLayout(width: Int32.max, height: Int32.max)
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }

    @Test
    func bufferLayoutRejectsByteCountAboveWaylandInt32Limit() {
        #expect(throws: RuntimeError.self) {
            _ = try BufferLayout(width: Int32.max / 4, height: 2)
        }
    }

    @Test
    func bufferBusyStateTracksReusableBuffers() {
        var state = BufferBusyState()
        #expect(!state.isBusy)
        #expect(state.isReusable)
        #expect(state.lifecycle == .available)
        let didAcquire = state.acquireForDrawing()
        #expect(didAcquire)
        #expect(!state.isReusable)
        let didMarkPending = state.markPendingRelease(commitGeneration: 9)
        #expect(didMarkPending)
        #expect(state.isBusy)
        #expect(state.lifecycle == .pendingRelease(commitGeneration: 9))
        state.markReleased()
        #expect(!state.isBusy)
        #expect(state.isReusable)
        #expect(state.lifecycle == .available)
    }
    @Test
    func acquiredBufferCannotBeAcquiredTwice() {
        var state = BufferBusyState()
        let firstAcquire = state.acquireForDrawing()
        let secondAcquire = state.acquireForDrawing()
        #expect(firstAcquire)
        #expect(!secondAcquire)
        #expect(state.lifecycle == .acquiredForDrawing)
    }
    @Test
    func releaseAfterDestroyedDoesNotMakeBufferReusable() {
        var state = BufferBusyState()
        let didAcquire = state.acquireForDrawing()
        #expect(didAcquire)
        state.markRetired(reason: .destroyed)
        state.markReleased()
        #expect(!state.isBusy)
        #expect(!state.isReusable)
        #expect(
            state.lifecycle
                == .retired(reason: .destroyed, pendingReleaseGeneration: nil)
        )
    }
    @Test
    func retiredPendingReleaseBufferStaysBusyUntilRelease() {
        var state = BufferBusyState()
        let didAcquire = state.acquireForDrawing()
        #expect(didAcquire)
        let didMarkPending = state.markPendingRelease(commitGeneration: 4)
        #expect(didMarkPending)
        state.markRetired(reason: .resized)
        #expect(state.isBusy)
        #expect(!state.isReusable)
        #expect(
            state.lifecycle
                == .retired(reason: .resized, pendingReleaseGeneration: 4)
        )
        state.markReleased()
        #expect(!state.isBusy)
        #expect(!state.isReusable)
        #expect(
            state.lifecycle
                == .retired(reason: .resized, pendingReleaseGeneration: nil)
        )
    }
    @Test
    func acquiredBufferCanBeRetiredBeforeCommit() {
        var state = BufferBusyState()
        let didAcquire = state.acquireForDrawing()
        #expect(didAcquire)
        state.markRetired(reason: .resized)
        #expect(!state.isBusy)
        #expect(!state.isReusable)
        #expect(
            state.lifecycle
                == .retired(reason: .resized, pendingReleaseGeneration: nil)
        )
    }
    @Test
    func markReleasedIsIdempotentOnAvailableBuffer() {
        var state = BufferBusyState()
        state.markReleased()
        state.markReleased()
        #expect(!state.isBusy)
        #expect(state.isReusable)
        #expect(state.lifecycle == .available)
    }
    @Test
    func retiredBufferCannotBecomePendingRelease() {
        var state = BufferBusyState()
        state.markRetired(reason: .resized)
        let didMarkPending = state.markPendingRelease(commitGeneration: 11)
        #expect(!didMarkPending)
        #expect(!state.isBusy)
        #expect(!state.isReusable)
        #expect(
            state.lifecycle
                == .retired(reason: .resized, pendingReleaseGeneration: nil)
        )
    }
    @Test
    func availableBufferCannotBecomePendingReleaseWithoutAcquire() {
        var state = BufferBusyState()
        let didMarkPending = state.markPendingRelease(commitGeneration: 12)
        #expect(!didMarkPending)
        #expect(!state.isBusy)
        #expect(state.isReusable)
        #expect(state.lifecycle == .available)
    }
    @Test
    func pendingReleaseGenerationCannotBeOverwritten() {
        var state = BufferBusyState()
        let didAcquire = state.acquireForDrawing()
        #expect(didAcquire)
        let didMarkInitialPending = state.markPendingRelease(commitGeneration: 13)
        let didOverwritePending = state.markPendingRelease(commitGeneration: 14)
        #expect(didMarkInitialPending)
        #expect(!didOverwritePending)
        #expect(state.lifecycle == .pendingRelease(commitGeneration: 13))
    }
}
