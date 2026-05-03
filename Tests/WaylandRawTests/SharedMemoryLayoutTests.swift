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
    func bufferBusyStateTracksReusableBuffers() {
        var state = BufferBusyState()

        #expect(!state.isBusy)
        #expect(state.isReusable)
        #expect(state.lifecycle == .available)

        let didAcquire = state.acquireForDrawing()
        #expect(didAcquire)
        #expect(!state.isReusable)

        state.markPendingRelease(commitGeneration: 9)
        #expect(state.isBusy)
        #expect(state.lifecycle == .pendingRelease(commitGeneration: 9))

        state.markReleased()
        #expect(!state.isBusy)
        #expect(state.isReusable)
        #expect(state.lifecycle == .available)
    }

    @Test
    func retiredPendingReleaseBufferStaysBusyUntilRelease() {
        var state = BufferBusyState()

        let didAcquire = state.acquireForDrawing()
        #expect(didAcquire)
        state.markPendingRelease(commitGeneration: 4)
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
}
