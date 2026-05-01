import Testing

@testable import WaylandClient

@Suite
struct WaylandClientTests {
    @Test
    func windowConfigurationRejectsInvalidInitialDimensionsAndBufferCount() {
        #expect(
            throws: ClientError.invalidWindowConfiguration(
                "initialWidth must be greater than zero"
            )
        ) {
            try WindowConfiguration(initialWidth: 0).validate()
        }

        #expect(
            throws: ClientError.invalidWindowConfiguration(
                "initialHeight must be greater than zero"
            )
        ) {
            try WindowConfiguration(initialHeight: -1).validate()
        }

        #expect(
            throws: ClientError.invalidWindowConfiguration(
                "bufferCount must be greater than zero"
            )
        ) {
            try WindowConfiguration(bufferCount: 0).validate()
        }
    }

    @Test
    func windowConfigurationRejectsCStringsThatWouldTruncateAtWaylandBoundary() {
        #expect(
            throws: ClientError.invalidWindowConfiguration(
                "title must not contain embedded NUL bytes"
            )
        ) {
            try WindowConfiguration(title: "visible\0hidden").validate()
        }

        #expect(
            throws: ClientError.invalidWindowConfiguration("appID must not be empty")
        ) {
            try WindowConfiguration(appID: "").validate()
        }

        #expect(
            throws: ClientError.invalidWindowConfiguration(
                "appID must not contain embedded NUL bytes"
            )
        ) {
            try WindowConfiguration(appID: "org.example\0Hidden").validate()
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
            throws: ClientError.invalidDisplayState(
                "rawInputQueueCapacity must be greater than zero"
            )
        ) {
            try DisplayConfiguration(
                inputPipeline: InputPipelineConfiguration(rawInputQueueCapacity: 0)
            ).validate()
        }

        #expect(
            throws: ClientError.invalidDisplayState(
                "pendingInputEventCapacity must be greater than zero"
            )
        ) {
            try DisplayConfiguration(
                inputPipeline: InputPipelineConfiguration(pendingInputEventCapacity: 0)
            ).validate()
        }

        #expect(
            throws: ClientError.invalidDisplayState(
                "diagnostics capacity must be greater than zero"
            )
        ) {
            try DisplayConfiguration(
                diagnostics: DiagnosticsConfiguration(capacity: 0)
            ).validate()
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
