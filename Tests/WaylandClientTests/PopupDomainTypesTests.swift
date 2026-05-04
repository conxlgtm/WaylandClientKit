import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct PopupDomainTypesTests {
    @Test
    func logicalRectRejectsNonPositiveSize() {
        #expect(throws: (any Error).self) {
            _ = try LogicalRect(x: 0, y: 0, width: 0, height: 10)
        }
        #expect(throws: (any Error).self) {
            _ = try LogicalRect(x: 0, y: 0, width: 10, height: -1)
        }
    }

    @Test
    func popupPositionerMapsPublicValuesToRawXDGValues() throws {
        let positioner = PopupPositioner(
            anchorRect: try LogicalRect(x: 10, y: 20, width: 30, height: 40),
            size: try PositiveLogicalSize(width: 320, height: 240),
            anchor: .bottomRight,
            gravity: .topLeft,
            constraintAdjustment: [.slideX, .flipY, .resizeX],
            offset: LogicalOffset(x: -4, y: 8)
        )

        #expect(positioner.anchor.rawXDGAnchor == .bottomRight)
        #expect(positioner.gravity.rawXDGGravity == .topLeft)
        #expect(
            positioner.constraintAdjustment.rawXDGConstraintAdjustment
                == [.slideX, .flipY, .resizeX]
        )
        #expect(positioner.offset == LogicalOffset(x: -4, y: 8))
    }

    @Test
    func popupAnchorMapsEveryClosedCaseToRawXDGValue() {
        let cases: [(PopupAnchor, WaylandRaw.RawXDGPositionerAnchor)] = [
            (.none, .none),
            (.top, .top),
            (.bottom, .bottom),
            (.left, .left),
            (.right, .right),
            (.topLeft, .topLeft),
            (.bottomLeft, .bottomLeft),
            (.topRight, .topRight),
            (.bottomRight, .bottomRight),
        ]

        for (anchor, rawAnchor) in cases {
            #expect(anchor.rawXDGAnchor == rawAnchor)
        }
    }

    @Test
    func popupGravityMapsEveryClosedCaseToRawXDGValue() {
        let cases: [(PopupGravity, WaylandRaw.RawXDGPositionerGravity)] = [
            (.none, .none),
            (.top, .top),
            (.bottom, .bottom),
            (.left, .left),
            (.right, .right),
            (.topLeft, .topLeft),
            (.bottomLeft, .bottomLeft),
            (.topRight, .topRight),
            (.bottomRight, .bottomRight),
        ]

        for (gravity, rawGravity) in cases {
            #expect(gravity.rawXDGGravity == rawGravity)
        }
    }

    @Test
    func popupConstraintAdjustmentBuildsOnlyFromClosedCases() {
        let adjustment = PopupConstraintAdjustment([.slideX, .flipY])
            .union(.resizeX)

        #expect(adjustment.contains(.slideX))
        #expect(adjustment.contains(.flipY))
        #expect(adjustment.contains(.resizeX))
        #expect(!adjustment.contains(.slideY))
        #expect(adjustment.rawXDGConstraintAdjustment == [.slideX, .flipY, .resizeX])
    }

    @Test
    func popupConfigurationCarriesExplicitGrabSerial() throws {
        let positioner = PopupPositioner(
            anchorRect: try LogicalRect(x: 0, y: 0, width: 1, height: 1),
            size: try PositiveLogicalSize(width: 10, height: 10)
        )
        let configuration = PopupConfiguration(
            positioner: positioner,
            grab: .explicit(seatID: SeatID(rawValue: 7), serial: InputSerial(rawValue: 42))
        )

        #expect(configuration.positioner == positioner)
        #expect(
            configuration.grab
                == .explicit(
                    seatID: SeatID(rawValue: 7),
                    serial: InputSerial(rawValue: 42)
                )
        )
    }

    @Test
    func popupConfigureStateLatchesPlacementAndAcksOnlyAfterSurfaceConfigure() throws {
        let state = PopupConfigureState()

        state.handlePopupConfigure(
            RawXDGPopupConfigure(x: 4, y: 8, width: 120, height: 64)
        )
        #expect(!state.hasReceivedInitialConfigure)
        #expect(state.consumeLatestConfigure() == nil)

        let sequence = try #require(state.handleSurfaceConfigure(serial: 99))

        #expect(state.hasReceivedInitialConfigure)
        #expect(sequence.serial == 99)
        #expect(sequence.placement.origin == LogicalOffset(x: 4, y: 8))
        #expect(sequence.placement.size == (try PositiveLogicalSize(width: 120, height: 64)))
        #expect(state.consumeLatestConfigure() == sequence)
        #expect(state.consumeLatestConfigure() == nil)
    }

    @Test
    func popupConfigureStateRejectsSurfaceConfigureWithoutPopupPayload() {
        let state = PopupConfigureState()

        #expect(state.handleSurfaceConfigure(serial: 42) == nil)
        #expect(!state.hasReceivedInitialConfigure)
    }

    @Test
    func popupConfigureStateRecordsInvalidPopupConfigureSize() throws {
        let state = PopupConfigureState()

        state.handlePopupConfigure(
            RawXDGPopupConfigure(x: 0, y: 0, width: 0, height: 10)
        )
        #expect(state.handleSurfaceConfigure(serial: 1) == nil)
        #expect(throws: (any Error).self) {
            try state.throwPendingErrorIfAny()
        }
    }
}
