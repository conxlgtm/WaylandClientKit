import CWaylandProtocols
import Foundation
import Testing

@testable import WaylandClient

// swiftlint:disable type_body_length
@Suite(
    .enabled(
        if: WindowControlRequestTestEnvironment.isEnabled,
        "Set WAYLAND_DISPLAY and SWIFT_WAYLAND_ENABLE_WINDOW_CONTROL_REQUEST_TESTS=1"
    ),
    .serialized
)
struct WindowControlPublicRequestTests {
    @Test
    func setTitleSendsTitleRequest() async throws {
        try await withWindowControlConnection { display, window in
            let topLevelPointer = try await requireTopLevelPointer(in: display, for: window)

            let record = try await recordTopLevelRequest {
                try await window.setTitle("Updated SwiftWayland Title")
            }

            #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_TITLE)
            #expect(record.topLevelAddress == topLevelPointer)
            #expect(record.text == "Updated SwiftWayland Title")
        }
    }

    @Test
    func setAppIDSendsAppIDRequest() async throws {
        try await withWindowControlConnection { display, window in
            let topLevelPointer = try await requireTopLevelPointer(in: display, for: window)

            let record = try await recordTopLevelRequest {
                try await window.setAppID("dev.swiftwayland.updated")
            }

            #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_APP_ID)
            #expect(record.topLevelAddress == topLevelPointer)
            #expect(record.text == "dev.swiftwayland.updated")
        }
    }

    @Test
    func setMaximumSizeSendsProtocolSizeAndNilClearsWithZeroes() async throws {
        try await withWindowControlConnection { display, window in
            let topLevelPointer = try await requireTopLevelPointer(in: display, for: window)

            let sizeRecord = try await recordTopLevelRequest {
                try await window.setMaximumSize(
                    try PositiveLogicalSize(width: 1_024, height: 768)
                )
            }

            #expect(sizeRecord.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MAX_SIZE)
            #expect(sizeRecord.topLevelAddress == topLevelPointer)
            #expect(sizeRecord.width == 1_024)
            #expect(sizeRecord.height == 768)

            let clearRecord = try await recordTopLevelRequest {
                try await window.setMaximumSize(nil)
            }

            #expect(clearRecord.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MAX_SIZE)
            #expect(clearRecord.topLevelAddress == topLevelPointer)
            #expect(clearRecord.width == 0)
            #expect(clearRecord.height == 0)
        }
    }

    @Test
    func requestMaximizeSendsSetMaximized() async throws {
        try await withWindowControlConnection { display, window in
            let topLevelPointer = try await requireTopLevelPointer(in: display, for: window)

            let record = try await recordTopLevelRequest {
                try await window.requestMaximize()
            }

            #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MAXIMIZED)
            #expect(record.topLevelAddress == topLevelPointer)
        }
    }

    @Test
    func requestUnmaximizeSendsUnsetMaximized() async throws {
        try await withWindowControlConnection { display, window in
            let topLevelPointer = try await requireTopLevelPointer(in: display, for: window)

            let record = try await recordTopLevelRequest {
                try await window.requestUnmaximize()
            }

            #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_UNSET_MAXIMIZED)
            #expect(record.topLevelAddress == topLevelPointer)
        }
    }

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
            let topLevelPointer = try await requireTopLevelPointer(in: display, for: window)

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
    func requestFullscreenWithoutOutputSendsNilOutput() async throws {
        try await withWindowControlConnection { display, window in
            let topLevelPointer = try await requireTopLevelPointer(in: display, for: window)

            let record = try await recordTopLevelRequest {
                try await window.requestFullscreen()
            }

            #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_FULLSCREEN)
            #expect(record.topLevelAddress == topLevelPointer)
            #expect(record.outputAddress == nil)
        }
    }

    @Test
    func requestExitFullscreenSendsUnsetFullscreen() async throws {
        try await withWindowControlConnection { display, window in
            let topLevelPointer = try await requireTopLevelPointer(in: display, for: window)

            let record = try await recordTopLevelRequest {
                try await window.requestExitFullscreen()
            }

            #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_UNSET_FULLSCREEN)
            #expect(record.topLevelAddress == topLevelPointer)
        }
    }

    @Test
    func requestMinimizeSendsSetMinimized() async throws {
        try await withWindowControlConnection { display, window in
            let topLevelPointer = try await requireTopLevelPointer(in: display, for: window)

            let record = try await recordTopLevelRequest {
                try await window.requestMinimize()
            }

            #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MINIMIZED)
            #expect(record.topLevelAddress == topLevelPointer)
        }
    }

    @Test
    func setMinimumSizeSendsProtocolSizeAndNilClearsWithZeroes() async throws {
        try await withWindowControlConnection { display, window in
            let topLevelPointer = try await requireTopLevelPointer(in: display, for: window)

            let sizeRecord = try await recordTopLevelRequest {
                try await window.setMinimumSize(
                    try PositiveLogicalSize(width: 320, height: 240)
                )
            }

            #expect(sizeRecord.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MIN_SIZE)
            #expect(sizeRecord.topLevelAddress == topLevelPointer)
            #expect(sizeRecord.width == 320)
            #expect(sizeRecord.height == 240)

            let clearRecord = try await recordTopLevelRequest {
                try await window.setMinimumSize(nil)
            }

            #expect(clearRecord.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MIN_SIZE)
            #expect(clearRecord.topLevelAddress == topLevelPointer)
            #expect(clearRecord.width == 0)
            #expect(clearRecord.height == 0)
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
    func requestInteractiveMoveUsesSeatAndSerial() async throws {
        try await withWindowControlConnection { display, window in
            try await withSeatForRecordedRequest(in: display, windowID: window.id) { seat in
                let topLevelPointer = try await requireTopLevelPointer(
                    in: display,
                    for: window
                )

                let record = try await recordTopLevelRequest {
                    try await window.requestInteractiveMove(
                        seatID: seat.id,
                        serial: InputSerial(rawValue: 33)
                    )
                }

                #expect(record.kind == SWL_TEST_XDG_TOPLEVEL_REQUEST_MOVE)
                #expect(record.topLevelAddress == topLevelPointer)
                #expect(record.seatAddress == seat.pointerAddress)
                #expect(record.serial == 33)
            }
        }
    }

    @Test
    func requestInteractiveResizeUsesSeatSerialAndEdge() async throws {
        try await withWindowControlConnection { display, window in
            try await withSeatForRecordedRequest(in: display, windowID: window.id) { seat in
                let topLevelPointer = try await requireTopLevelPointer(
                    in: display,
                    for: window
                )

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
    func interactiveRequestsRejectUnknownSeat() async throws {
        try await withWindowControlConnection { _, window in
            let unknownSeat = SeatID(rawValue: UInt32.max)

            try await expectUnknownInteractionSeat(unknownSeat) {
                try await window.requestInteractiveMove(
                    seatID: unknownSeat,
                    serial: InputSerial(rawValue: 1)
                )
            }
            try await expectUnknownInteractionSeat(unknownSeat) {
                try await window.requestInteractiveResize(
                    seatID: unknownSeat,
                    serial: InputSerial(rawValue: 2),
                    edge: .left
                )
            }
            try await expectUnknownInteractionSeat(unknownSeat) {
                try await window.requestWindowMenu(
                    seatID: unknownSeat,
                    serial: InputSerial(rawValue: 3),
                    position: LogicalOffset(x: 0, y: 0)
                )
            }
        }
    }

    @Test
    func windowMenuUsesSeatSerialAndPosition() async throws {
        try await withWindowControlConnection { display, window in
            try await withSeatForRecordedRequest(in: display, windowID: window.id) { seat in
                let topLevelPointer = try await requireTopLevelPointer(
                    in: display,
                    for: window
                )

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
}
// swiftlint:enable type_body_length

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

private func requireTopLevelPointer(
    in display: WaylandDisplay,
    for window: Window
) async throws -> UInt {
    guard
        let pointer = try await display.rawTopLevelPointerAddressForTesting(
            window.id
        )
    else {
        Issue.record("Expected a live xdg_toplevel for \(window.id).")
        throw WindowControlRequestTestError.missingTopLevel
    }

    return pointer
}

private func expectUnknownInteractionSeat(
    _ seatID: SeatID,
    _ action: @Sendable () async throws -> Void
) async throws {
    do {
        try await action()
        Issue.record("Expected unknown interaction seat \(seatID) to throw.")
    } catch ClientError.invalidWindowState(
        .unknownWindowInteractionSeat(let thrownSeatID)
    ) {
        #expect(thrownSeatID == seatID)
    } catch {
        Issue.record("Expected unknown interaction seat error, got \(error).")
    }
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

private enum WindowControlRequestTestError: Error {
    case missingTopLevel
}

private enum WindowControlRequestTestEnvironment {
    static var isEnabled: Bool {
        let environment = ProcessInfo.processInfo.environment

        return environment["WAYLAND_DISPLAY"]?.isEmpty == false
            && environment["SWIFT_WAYLAND_ENABLE_WINDOW_CONTROL_REQUEST_TESTS"] == "1"
    }
}
