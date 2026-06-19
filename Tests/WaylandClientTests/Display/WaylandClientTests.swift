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
    func decorationPreferencePlansRawRequestSideEffects() {
        #expect(
            DecorationModeRequest(preference: .preferServerSide)
                == .set(.serverSide)
        )
        #expect(
            DecorationModeRequest(preference: .preferClientSide)
                == .set(.clientSide)
        )
        #expect(DecorationModeRequest(preference: .compositorDefault) == .unset)
    }

    @Test
    func unavailableDecorationManagerDiagnosticsOnlyReportForServerSidePreference() {
        #expect(
            WindowDecorationPreference.preferServerSide.shouldReportMissingDecorationManager
        )
        #expect(
            !WindowDecorationPreference.preferClientSide.shouldReportMissingDecorationManager
        )
        #expect(
            !WindowDecorationPreference.compositorDefault.shouldReportMissingDecorationManager
        )
    }

    @Test
    func unsupportedDecorationManagerVersionDiagnosticIncludesVersions() {
        let reason = DecorationUnavailableReason.unsupportedManagerVersion(
            advertised: RawVersion(1),
            minimum: RawVersion(2)
        )

        #expect(
            reason.diagnosticMessage
                == "Server-side decoration protocol v1 is unsupported; "
                + "requires v2 or newer."
        )
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
    func softwareFrameWritesVisiblePixelsThroughMutableSpanRows() throws {
        var storage = [UInt32](repeating: 0, count: 6)
        let byteCount = storage.count * MemoryLayout<UInt32>.stride

        // swiftlint:disable:next closure_body_length
        try unsafe storage.withUnsafeMutableBufferPointer { buffer in
            let frame = try unsafe SoftwareFrame(
                id: softwareFrameTestBufferID(),
                width: 2,
                height: 2,
                stride: 3 * Int32(MemoryLayout<UInt32>.stride),
                geometry: try softwareFrameTestGeometry(width: 2, height: 2),
                bytes: unsafe UnsafeMutableRawBufferPointer(
                    start: UnsafeMutableRawPointer(buffer.baseAddress),
                    count: byteCount
                )
            )

            frame.withXRGB8888Rows { row, pixels in
                #expect(pixels.count == 2)
                unsafe pixels[unchecked: 0] = UInt32(row * 10 + 1)
                unsafe pixels[unchecked: 1] = UInt32(row * 10 + 2)
            }

            frame.withBuffer { buffer in
                #expect(buffer.id == frame.id)
                #expect(buffer.width == frame.width)
                #expect(buffer.height == frame.height)
                #expect(buffer.stride == frame.stride)
                #expect(buffer.geometry == frame.geometry)
                buffer.withMutableBytes { bytes in
                    bytes.storeBytes(
                        of: UInt32(99),
                        toByteOffset: 2 * MemoryLayout<UInt32>.stride,
                        as: UInt32.self
                    )
                }
            }

            #expect(frame.geometry.bufferSize == (try PositivePixelSize(width: 2, height: 2)))
        }

        #expect(storage == [1, 2, 99, 11, 12, 0])
    }

    @Test
    func softwareFrameRejectsStorageSmallerThanLayout() throws {
        var storage = [UInt32](repeating: 0, count: 3)
        let byteCount = storage.count * MemoryLayout<UInt32>.stride

        _ = unsafe storage.withUnsafeMutableBufferPointer { buffer in
            #expect(
                throws: ClientError.invalidWindowState(
                    .softwareFrameLayout(
                        .storageTooSmall(
                            requiredByteCount: 2 * 3 * MemoryLayout<UInt32>.stride,
                            actualByteCount: byteCount
                        )
                    )
                )
            ) {
                _ = try unsafe SoftwareFrame(
                    id: softwareFrameTestBufferID(),
                    width: 2,
                    height: 2,
                    stride: 3 * Int32(MemoryLayout<UInt32>.stride),
                    geometry: try softwareFrameTestGeometry(width: 2, height: 2),
                    bytes: unsafe UnsafeMutableRawBufferPointer(
                        start: UnsafeMutableRawPointer(buffer.baseAddress),
                        count: byteCount
                    )
                )
            }
        }
    }
}

private func softwareFrameTestGeometry(width: Int32, height: Int32) throws
    -> SoftwareFrameGeometry
{
    SoftwareFrameGeometry(
        surface: try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: width, height: height),
            scale: .one
        )
    )
}

private func softwareFrameTestBufferID() -> SoftwareFrameBufferID {
    SoftwareFrameBufferID(rawValue: 1)
}
