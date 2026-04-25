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

        state.markBusy()
        #expect(state.isBusy)

        state.markReleased()
        #expect(!state.isBusy)
    }
}
