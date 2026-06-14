import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PointerWarpDomainTypesTests {
    @Test
    func fixedPointerWarpPositionRejectsNegativeCoordinates() throws {
        let windowSize = try PositiveLogicalSize(width: 10, height: 20)
        let position = LogicalOffset(x: -1, y: 0)

        #expect(
            throws: PointerWarpError.invalidPosition(
                position: position,
                windowSize: windowSize
            )
        ) {
            _ = try FixedPointerWarpPosition(position: position, windowSize: windowSize)
        }
    }

    @Test
    func fixedPointerWarpPositionRejectsCoordinatesOutsideWindow() throws {
        let windowSize = try PositiveLogicalSize(width: 10, height: 20)
        let position = LogicalOffset(x: 10, y: 19)

        #expect(
            throws: PointerWarpError.invalidPosition(
                position: position,
                windowSize: windowSize
            )
        ) {
            _ = try FixedPointerWarpPosition(position: position, windowSize: windowSize)
        }
    }

    @Test
    func fixedPointerWarpPositionConvertsLogicalCoordinatesToWaylandFixed() throws {
        let windowSize = try PositiveLogicalSize(width: 10, height: 20)
        let position = try FixedPointerWarpPosition(
            position: LogicalOffset(x: 3, y: 4),
            windowSize: windowSize
        )

        #expect(position.x == WaylandFixed(rawValue: 768))
        #expect(position.y == WaylandFixed(rawValue: 1_024))
    }

    @Test
    func requestPreflightReportsUnavailableProtocol() {
        let seatID = SeatID(rawValue: 4)

        #expect(throws: PointerWarpError.unavailable) {
            try PointerCaptureManager.validatePointerWarpRequest(
                isShutDown: false,
                hasPointerWarp: false,
                hasSeat: true,
                seatHasPointerDevice: true,
                seatID: seatID
            )
        }
    }

    @Test
    func requestPreflightReportsUnknownSeat() {
        let seatID = SeatID(rawValue: 5)

        #expect(throws: PointerWarpError.unknownSeat(seatID)) {
            try PointerCaptureManager.validatePointerWarpRequest(
                isShutDown: false,
                hasPointerWarp: true,
                hasSeat: false,
                seatHasPointerDevice: false,
                seatID: seatID
            )
        }
    }

    @Test
    func requestPreflightReportsPointerUnavailable() {
        let seatID = SeatID(rawValue: 6)

        #expect(throws: PointerWarpError.pointerUnavailable(seatID)) {
            try PointerCaptureManager.validatePointerWarpRequest(
                isShutDown: false,
                hasPointerWarp: true,
                hasSeat: true,
                seatHasPointerDevice: false,
                seatID: seatID
            )
        }
    }

    @Test
    func requestPreflightReportsDisplayClosed() {
        let seatID = SeatID(rawValue: 7)

        #expect(throws: PointerWarpError.displayClosed) {
            try PointerCaptureManager.validatePointerWarpRequest(
                isShutDown: true,
                hasPointerWarp: true,
                hasSeat: true,
                seatHasPointerDevice: true,
                seatID: seatID
            )
        }
    }

    @Test
    func requestErrorMappingPreservesPointerUnavailable() {
        let seatID = SeatID(rawValue: 8)

        #expect(
            PointerCaptureManager.mapPointerWarpRequestError(
                RuntimeError.bindFailed("wl_pointer"),
                seatID: seatID
            ) == .pointerUnavailable(seatID)
        )
    }

    @Test
    func requestErrorMappingReportsTypedRequestFailure() {
        let seatID = SeatID(rawValue: 9)
        let error = PointerCaptureManager.mapPointerWarpRequestError(
            RuntimeError.protocolError(interfaceName: "wp_pointer_warp_v1", objectID: 44, code: 2),
            seatID: seatID
        )

        guard case .requestFailed(let detail) = error else {
            Issue.record("Expected requestFailed, got \(error)")
            return
        }

        #expect(detail.contains("wp_pointer_warp_v1"))
    }

    @Test
    func displayCoreReportsPointerWarpDisplayClosed() {
        let core = DisplayCore(eventHub: DisplayEventHub())
        core.close()

        #expect(throws: PointerWarpError.displayClosed) {
            try core.requestPointerWarp(
                windowID: WindowID(rawValue: 1),
                seatID: SeatID(rawValue: 1),
                position: LogicalOffset(x: 0, y: 0),
                serial: InputSerial(rawValue: 1)
            )
        }
    }

    @Test
    func displayCoreReportsUnknownPointerWarpWindow() {
        let core = DisplayCore(eventHub: DisplayEventHub())
        let windowID = WindowID(rawValue: 44)

        #expect(throws: PointerWarpError.unknownWindow(windowID)) {
            try core.requestPointerWarp(
                windowID: windowID,
                seatID: SeatID(rawValue: 1),
                position: LogicalOffset(x: 0, y: 0),
                serial: InputSerial(rawValue: 1)
            )
        }
    }

    @Test
    func publicOwnershipValidationReportsForeignWindow() {
        let windowID = WindowID(rawValue: 45)

        #expect(throws: PointerWarpError.foreignWindow(windowID)) {
            try WaylandDisplay.validatePointerWarpWindowOwnership(
                windowID: windowID,
                isOwned: false
            )
        }
    }

    @Test
    func displayCoreWindowValidationReportsClosedWindow() {
        let windowID = WindowID(rawValue: 46)

        #expect(throws: PointerWarpError.closedWindow(windowID)) {
            try DisplayCore.validatePointerWarpWindowState(
                isDisplayClosed: false,
                windowID: windowID,
                windowExists: true,
                windowIsClosed: true
            )
        }
    }
}
