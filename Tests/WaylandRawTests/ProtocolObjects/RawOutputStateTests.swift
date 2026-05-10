import Testing

@testable import WaylandRaw

@Suite
struct RawOutputStateTests {
    @Test
    func wlOutputVersionOnePublishesCoreChangesWithoutDone() {
        var state = RawOutputState()

        let shouldPublish = state.applyCoreEvent(
            .geometry(rawGeometry(x: 10, y: 20)),
            version: RawVersion(1)
        )
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 7), version: RawVersion(1))

        #expect(shouldPublish)
        #expect(snapshot.geometry?.x == 10)
        #expect(snapshot.geometry?.y == 20)
    }

    @Test
    func wlOutputVersionTwoBatchesCoreChangesUntilDone() {
        var state = RawOutputState()

        let geometryShouldPublish = state.applyCoreEvent(
            .geometry(rawGeometry(x: 30, y: 40)),
            version: RawVersion(2)
        )
        let doneShouldPublish = state.applyCoreEvent(.done, version: RawVersion(2))

        #expect(!geometryShouldPublish)
        #expect(doneShouldPublish)
    }

    @Test
    func xdgOutputPublishesWhenWLOutputDoneIsUnavailable() {
        var state = RawOutputState()

        let positionShouldPublish = state.applyXDGOutputEvent(
            .logicalPosition(x: 1, y: 2),
            outputVersion: RawVersion(1),
            xdgOutputVersion: RawVersion(3)
        )
        let sizeShouldPublish = state.applyXDGOutputEvent(
            .logicalSize(width: 640, height: 480),
            outputVersion: RawVersion(1),
            xdgOutputVersion: RawVersion(3)
        )
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 8), version: RawVersion(1))

        #expect(positionShouldPublish)
        #expect(sizeShouldPublish)
        #expect(snapshot.logicalGeometry?.x == 1)
        #expect(snapshot.logicalGeometry?.y == 2)
        #expect(snapshot.logicalGeometry?.width == 640)
        #expect(snapshot.logicalGeometry?.height == 480)
    }

    @Test
    func xdgOutputVersionTwoBatchesWithXDGDoneWhenWLOutputDoneIsUnavailable() {
        var state = RawOutputState()

        let positionShouldPublish = state.applyXDGOutputEvent(
            .logicalPosition(x: 1, y: 2),
            outputVersion: RawVersion(1),
            xdgOutputVersion: RawVersion(2)
        )
        let doneShouldPublish = state.applyXDGOutputEvent(
            .done,
            outputVersion: RawVersion(1),
            xdgOutputVersion: RawVersion(2)
        )

        #expect(!positionShouldPublish)
        #expect(doneShouldPublish)
    }

    @Test
    func xdgDescriptionUpdatesReplaceEarlierXDGDescription() {
        var state = RawOutputState()

        _ = state.applyXDGOutputEvent(
            .description("Initial panel"),
            outputVersion: RawVersion(2),
            xdgOutputVersion: RawVersion(3)
        )
        _ = state.applyXDGOutputEvent(
            .description("Renamed panel"),
            outputVersion: RawVersion(2),
            xdgOutputVersion: RawVersion(3)
        )
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 9), version: RawVersion(2))

        #expect(snapshot.description == "Renamed panel")
    }

    @Test
    func wlDescriptionTakesPrecedenceOverLaterXDGDescription() {
        var state = RawOutputState()

        _ = state.applyXDGOutputEvent(
            .description("XDG description"),
            outputVersion: RawVersion(4),
            xdgOutputVersion: RawVersion(3)
        )
        _ = state.applyCoreEvent(
            .description("wl_output description"),
            version: RawVersion(4)
        )
        _ = state.applyXDGOutputEvent(
            .description("Stale XDG description"),
            outputVersion: RawVersion(4),
            xdgOutputVersion: RawVersion(3)
        )
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 10), version: RawVersion(4))

        #expect(snapshot.description == "wl_output description")
    }

    private func rawGeometry(
        x: Int32 = 0,
        y: Int32 = 0
    ) -> RawOutputGeometry {
        RawOutputGeometry(
            x: x,
            y: y,
            physicalWidthMillimeters: 600,
            physicalHeightMillimeters: 340,
            subpixel: 0,
            make: "Acme",
            model: "Panel",
            transform: 0
        )
    }
}
