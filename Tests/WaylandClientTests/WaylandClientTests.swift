import Testing

@testable import WaylandClient

@Suite
struct WaylandClientTests {
    @Test
    func windowConfigurationRejectsInvalidInitialDimensionsAndBufferCount() {
        #expect(
            throws: ClientError.invalidWindowConfiguration(.nonPositiveInitialWidth(0))
        ) {
            _ = try WindowConfiguration(initialWidth: 0)
        }

        #expect(
            throws: ClientError.invalidWindowConfiguration(.nonPositiveInitialHeight(-1))
        ) {
            _ = try WindowConfiguration(initialHeight: -1)
        }

        #expect(
            throws: ClientError.invalidWindowConfiguration(.nonPositiveBufferCount(0))
        ) {
            _ = try WindowConfiguration(bufferCount: 0)
        }
    }

    @Test
    func windowConfigurationRejectsCStringsThatWouldTruncateAtWaylandBoundary() {
        #expect(
            throws: ClientError.invalidWindowConfiguration(.interiorNUL(field: "title"))
        ) {
            _ = try WindowConfiguration(title: "visible\0hidden")
        }

        #expect(
            throws: ClientError.invalidWindowConfiguration(.emptyString(field: "appID"))
        ) {
            _ = try WindowConfiguration(appID: "")
        }

        #expect(
            throws: ClientError.invalidWindowConfiguration(.interiorNUL(field: "appID"))
        ) {
            _ = try WindowConfiguration(appID: "org.example\0Hidden")
        }
    }

    @Test
    func pointerCursorRejectsCStringsThatWouldTruncateAtCursorBoundary() {
        #expect(
            throws: ClientError.invalidCursorConfiguration(
                "Pointer cursor names must not contain embedded NUL bytes"
            )
        ) {
            _ = try PointerCursor(name: "left_ptr\0fallback")
        }
    }

    @Test
    func displayConfigurationRejectsInvalidInternalCapacities() {
        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .rawInputQueueCapacity,
                value: 0
            )
        ) {
            _ = try InputPipelineConfiguration(rawInputQueueCapacity: 0)
        }

        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .pendingInputEventCapacity,
                value: 0
            )
        ) {
            _ = try InputPipelineConfiguration(pendingInputEventCapacity: 0)
        }

        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .diagnosticsCapacity,
                value: 0
            )
        ) {
            _ = try DiagnosticsConfiguration(capacity: 0)
        }
    }

    @Test
    func softwareFrameWritesVisiblePixelsThroughMutableSpanRows() throws {
        var storage = [UInt32](repeating: 0, count: 6)
        let byteCount = storage.count * MemoryLayout<UInt32>.stride

        try storage.withUnsafeMutableBufferPointer { buffer in
            let frame = try SoftwareFrame(
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

    @Test
    func softwareFrameRejectsStorageSmallerThanLayout() throws {
        var storage = [UInt32](repeating: 0, count: 3)
        let byteCount = storage.count * MemoryLayout<UInt32>.stride

        _ = storage.withUnsafeMutableBufferPointer { buffer in
            #expect(
                throws: ClientError.invalidWindowState(
                    "software frame storage is smaller than its layout"
                )
            ) {
                _ = try SoftwareFrame(
                    width: 2,
                    height: 2,
                    stride: 3 * Int32(MemoryLayout<UInt32>.stride),
                    bytes: UnsafeMutableRawBufferPointer(
                        start: UnsafeMutableRawPointer(buffer.baseAddress),
                        count: byteCount
                    )
                )
            }
        }
    }
}
