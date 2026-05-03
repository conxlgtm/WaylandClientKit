import Testing
import WaylandRaw

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
    func windowConfigurationDefaultsToServerSideDecorationPreference() throws {
        #expect(WindowConfiguration.default.decorationPreference == .preferServerSide)
        #expect(
            try WindowConfiguration().decorationPreference == .preferServerSide
        )
    }

    @Test
    func decorationPreferenceMapsToRawModeRequest() {
        #expect(WindowDecorationPreference.preferServerSide.requestedRawMode == .serverSide)
        #expect(WindowDecorationPreference.preferClientSide.requestedRawMode == .clientSide)
        #expect(WindowDecorationPreference.compositorDefault.requestedRawMode == nil)
    }

    @Test
    func pointerCursorRejectsCStringsThatWouldTruncateAtCursorBoundary() {
        #expect(
            throws: ClientError.cursor(
                .invalidConfiguration(.cursorNameContainsInteriorNUL)
            )
        ) {
            _ = try PointerCursor(name: "left_ptr\0fallback")
        }
    }

    @Test
    func pointerCursorRejectsEmptyName() {
        #expect(throws: ClientError.cursor(.invalidConfiguration(.emptyCursorName))) {
            _ = try PointerCursor(name: "")
        }
    }

    @Test
    func cursorConfigurationRejectsInvalidSize() {
        #expect(throws: CursorConfigurationError.invalidSize(0)) {
            _ = try CursorConfiguration(themeName: nil, size: 0)
        }
    }

    @Test
    func cursorConfigurationRejectsEmptyThemeName() {
        #expect(throws: CursorConfigurationError.emptyThemeName) {
            _ = try CursorConfiguration(themeName: "")
        }
    }

    @Test
    func cursorConfigurationAcceptsMinimumValidSizeAndThemeName() throws {
        let configuration = try CursorConfiguration(themeName: "default", size: 1)

        #expect(configuration.themeName == (try CursorThemeName("default")))
        #expect(configuration.size == (try CursorSize(1)))
    }

    @Test
    func displayConfigurationRejectsInvalidInternalCapacities() {
        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .displayEventCapacity,
                value: 0
            )
        ) {
            _ = try EventStreamConfiguration(displayEventCapacity: 0)
        }

        #expect(
            throws: DisplayConfigurationError.nonPositiveCapacity(
                field: .inputEventCapacity,
                value: 0
            )
        ) {
            _ = try EventStreamConfiguration(inputEventCapacity: 0)
        }

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
    func displayConfigurationAcceptsMinimumValidCapacities() throws {
        let eventStreams = try EventStreamConfiguration(
            displayEventCapacity: 1,
            inputEventCapacity: 1
        )
        let inputPipeline = try InputPipelineConfiguration(
            rawInputQueueCapacity: 1,
            pendingInputEventCapacity: 1
        )
        let diagnostics = try DiagnosticsConfiguration(capacity: 1)

        #expect(
            eventStreams.displayEventCapacity
                == (try EventStreamCapacity(1, field: .displayEventCapacity))
        )
        #expect(
            eventStreams.inputEventCapacity
                == (try EventStreamCapacity(1, field: .inputEventCapacity))
        )
        #expect(
            inputPipeline.rawInputQueueCapacity
                == (try InputQueueCapacity(1, field: .rawInputQueueCapacity))
        )
        #expect(
            inputPipeline.pendingInputEventCapacity
                == (try InputQueueCapacity(1, field: .pendingInputEventCapacity))
        )
        #expect(diagnostics.capacity == (try DiagnosticsCapacity(1)))
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
