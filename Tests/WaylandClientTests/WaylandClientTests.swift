import Testing

@testable import WaylandClient

@Suite
struct WaylandClientTests {
    @Test
    func waylandClientBootstrapIsReady() {
        #expect(WaylandClientBootstrap.ready)
    }

    @Test
    func softwareFrameWritesVisiblePixelsThroughMutableSpanRows() {
        var storage = [UInt32](repeating: 0, count: 6)
        let byteCount = storage.count * MemoryLayout<UInt32>.stride

        storage.withUnsafeMutableBufferPointer { buffer in
            let frame = SoftwareFrame(
                width: 2,
                height: 2,
                stride: 3 * Int32(MemoryLayout<UInt32>.stride),
                bytes: UnsafeMutableRawBufferPointer(
                    start: UnsafeMutableRawPointer(buffer.baseAddress),
                    count: byteCount
                )
            )

            frame.withXRGB8888Rows { row, pixels in
                #expect(pixels.count == 2)
                pixels[unchecked: 0] = UInt32(row * 10 + 1)
                pixels[unchecked: 1] = UInt32(row * 10 + 2)
            }
        }

        #expect(storage == [1, 2, 0, 11, 12, 0])
    }
}
