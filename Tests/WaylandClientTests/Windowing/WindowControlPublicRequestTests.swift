import CWaylandProtocols
import Foundation
import Testing

@testable import WaylandClient

@Suite(
    .enabled(
        if: WindowControlRequestTestEnvironment.isEnabled,
        "Set WAYLAND_DISPLAY and SWIFT_WAYLAND_ENABLE_WINDOW_CONTROL_REQUEST_TESTS=1"
    ),
    .serialized
)
struct WindowControlPublicRequestTests {
    @Test
    func requestFullscreenUsesResolvedOutputPointer() async throws {
        try await withWindowControlConnection { display, window in
            guard let output = try await display.firstRawOutputForTesting() else {
                Issue.record(
                    "Skipping fullscreen request test: compositor advertised no outputs.",
                    severity: .warning
                )
                return
            }
            guard
                let topLevelPointer = try await display.rawTopLevelPointerAddressForTesting(
                    window.id
                )
            else {
                Issue.record("Expected a live xdg_toplevel for \(window.id).")
                return
            }

            let record = try await recordTopLevelRequest {
                try await window.requestFullscreen(output: output.id)
            }

            #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_FULLSCREEN)
            #expect(record.topLevelAddress == topLevelPointer)
            #expect(record.outputAddress == output.pointerAddress)
        }
    }

    @Test
    func requestFullscreenRejectsUnknownOutputID() async throws {
        try await withWindowControlConnection { _, window in
            let unknownOutput = OutputID(rawValue: UInt32.max)

            do {
                try await window.requestFullscreen(output: unknownOutput)
                Issue.record("Expected unknown fullscreen output to throw.")
            } catch ClientError.invalidWindowState(
                .unknownWindowFullscreenOutput(let outputID)
            ) {
                #expect(outputID == unknownOutput)
            } catch {
                Issue.record("Expected unknown fullscreen output error, got \(error).")
            }
        }
    }

    @Test
    func requestInteractiveResizeUsesSeatSerialAndEdge() async throws {
        try await withWindowControlConnection { display, window in
            try await withSeatForRecordedRequest(in: display, windowID: window.id) { seat in
                guard
                    let topLevelPointer = try await display.rawTopLevelPointerAddressForTesting(
                        window.id
                    )
                else {
                    Issue.record("Expected a live xdg_toplevel for \(window.id).")
                    return
                }

                let record = try await recordTopLevelRequest {
                    try await window.requestInteractiveResize(
                        seatID: seat.id,
                        serial: InputSerial(rawValue: 44),
                        edge: .bottomRight
                    )
                }

                #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_RESIZE)
                #expect(record.topLevelAddress == topLevelPointer)
                #expect(record.seatAddress == seat.pointerAddress)
                #expect(record.serial == 44)
                #expect(record.value == WindowResizeEdge.bottomRight.rawXDGResizeEdge.rawValue)
            }
        }
    }

    @Test
    func setMinimumSizeNilClearsProtocolSizeWithZeroes() async throws {
        try await withWindowControlConnection { display, window in
            guard
                let topLevelPointer = try await display.rawTopLevelPointerAddressForTesting(
                    window.id
                )
            else {
                Issue.record("Expected a live xdg_toplevel for \(window.id).")
                return
            }

            let record = try await recordTopLevelRequest {
                try await window.setMinimumSize(nil)
            }

            #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MIN_SIZE)
            #expect(record.topLevelAddress == topLevelPointer)
            #expect(record.width == 0)
            #expect(record.height == 0)
        }
    }

    @Test
    func windowStateSnapshotThrowsBeforeInitialConfigure() async throws {
        try await withWindowControlConnection { _, window in
            do {
                _ = try await window.stateSnapshot
                Issue.record("Expected state snapshot before initial configure to throw.")
            } catch ClientError.window(
                window.id,
                .invalidLifecycleTransition(.mapBeforeInitialConfigure)
            ) {
                // Expected before the first compositor configure.
            } catch {
                Issue.record("Expected map-before-configure error, got \(error).")
            }
        }
    }

    @Test
    func windowMenuUsesSeatSerialAndPosition() async throws {
        try await withWindowControlConnection { display, window in
            try await withSeatForRecordedRequest(in: display, windowID: window.id) { seat in
                guard
                    let topLevelPointer = try await display.rawTopLevelPointerAddressForTesting(
                        window.id
                    )
                else {
                    Issue.record("Expected a live xdg_toplevel for \(window.id).")
                    return
                }

                let record = try await recordTopLevelRequest {
                    try await window.requestWindowMenu(
                        seatID: seat.id,
                        serial: InputSerial(rawValue: 55),
                        position: LogicalOffset(x: 12, y: -7)
                    )
                }

                #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SHOW_WINDOW_MENU)
                #expect(record.topLevelAddress == topLevelPointer)
                #expect(record.seatAddress == seat.pointerAddress)
                #expect(record.serial == 55)
                #expect(record.x == 12)
                #expect(record.y == -7)
            }
        }
    }

    private func withWindowControlConnection(
        _ body: @Sendable (WaylandDisplay, Window) async throws -> Void
    ) async throws {
        try await WaylandDisplay.withConnection(
            cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
            discoveryTimeoutMilliseconds: 5_000
        ) { display in
            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "SwiftWayland Window Control Test",
                    appID: "swift-wayland-window-control-test",
                    initialWidth: 160,
                    initialHeight: 120,
                    closeRequestPolicy: .requestOnly,
                    decorationPreference: .preferServerSide
                )
            )

            try await body(display, window)
        }
    }

    private func recordTopLevelRequest(
        _ request: @Sendable () async throws -> Void
    ) async throws -> RecordedTopLevelRequest {
        swl_test_xdg_request_recording_begin()
        defer {
            swl_test_xdg_request_recording_end()
        }

        try await request()
        return unsafe RecordedTopLevelRequest(swl_test_xdg_toplevel_request_record())
    }

    private func withSeatForRecordedRequest(
        in display: WaylandDisplay,
        windowID: WindowID,
        _ body: @Sendable ((id: SeatID, pointerAddress: UInt)) async throws -> Void
    ) async throws {
        if let seat = try await display.firstRawSeatForTesting() {
            try await body(seat)
            return
        }

        let insertedSeat = try await display.insertWindowInteractionSeatForTesting(
            windowID: windowID,
            seatID: SeatID(rawValue: UInt32.max - 1),
            pointerAddress: 0x5EA7_0001
        )
        do {
            try await body(insertedSeat)
            try await display.removeWindowInteractionSeatForTesting(
                windowID: windowID,
                seatID: insertedSeat.id
            )
        } catch let bodyError {
            do {
                try await display.removeWindowInteractionSeatForTesting(
                    windowID: windowID,
                    seatID: insertedSeat.id
                )
            } catch {
                Issue.record("Failed to remove testing interaction seat: \(error).")
            }
            throw bodyError
        }
    }
}

private struct RecordedTopLevelRequest: Sendable {
    let kind: swl_test_xdg_toplevel_request_kind
    let topLevelAddress: UInt?
    let seatAddress: UInt?
    let outputAddress: UInt?
    let serial: UInt32
    let x: Int32
    let y: Int32
    let width: Int32
    let height: Int32
    let value: UInt32

    init(_ record: swl_test_xdg_toplevel_request_record) {
        unsafe kind = record.kind
        unsafe topLevelAddress = Self.pointerAddress(record.toplevel)
        unsafe seatAddress = Self.pointerAddress(record.seat)
        unsafe outputAddress = Self.pointerAddress(record.output)
        unsafe serial = record.serial
        unsafe x = record.x
        unsafe y = record.y
        unsafe width = record.width
        unsafe height = record.height
        unsafe value = record.value
    }

    private static func pointerAddress(_ pointer: OpaquePointer?) -> UInt? {
        guard let pointer = unsafe pointer else { return nil }

        return unsafe UInt(bitPattern: UnsafeMutableRawPointer(pointer))
    }
}

private enum WindowControlRequestTestEnvironment {
    static var isEnabled: Bool {
        let environment = ProcessInfo.processInfo.environment

        return environment["WAYLAND_DISPLAY"]?.isEmpty == false
            && environment["SWIFT_WAYLAND_ENABLE_WINDOW_CONTROL_REQUEST_TESTS"] == "1"
    }
}
