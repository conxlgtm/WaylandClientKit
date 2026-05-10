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
    func invalidScaleEventDoesNotReplaceCurrentScale() {
        var state = RawOutputState()

        let validShouldPublish = state.applyCoreEvent(.scale(2), version: RawVersion(1))
        let invalidShouldPublish = state.applyCoreEvent(.scale(0), version: RawVersion(1))
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 16), version: RawVersion(1))

        #expect(validShouldPublish)
        #expect(!invalidShouldPublish)
        #expect(snapshot.scale == 2)
    }

    @Test
    func invalidCurrentModeClearsPreviousCurrentMode() {
        var state = RawOutputState()

        _ = state.applyCoreEvent(
            .mode(rawMode(width: 1_920, height: 1_080)),
            version: RawVersion(1)
        )
        let invalidShouldPublish = state.applyCoreEvent(
            .mode(rawMode(width: 0, height: 1_080)),
            version: RawVersion(1)
        )
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 17), version: RawVersion(1))

        #expect(invalidShouldPublish)
        #expect(snapshot.currentMode == nil)
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
    func invalidXDGLogicalSizeClearsPreviousLogicalGeometry() {
        var state = RawOutputState()

        _ = state.applyXDGOutputEvent(
            .logicalPosition(x: 1, y: 2),
            outputVersion: RawVersion(1),
            xdgOutputVersion: RawVersion(3)
        )
        _ = state.applyXDGOutputEvent(
            .logicalSize(width: 640, height: 480),
            outputVersion: RawVersion(1),
            xdgOutputVersion: RawVersion(3)
        )
        let invalidShouldPublish = state.applyXDGOutputEvent(
            .logicalSize(width: -1, height: 480),
            outputVersion: RawVersion(1),
            xdgOutputVersion: RawVersion(3)
        )
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 18), version: RawVersion(1))

        #expect(invalidShouldPublish)
        #expect(snapshot.logicalGeometry == nil)
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

    @Test
    func wlNameTakesPrecedenceOverXDGName() {
        var state = RawOutputState()

        _ = state.applyXDGOutputEvent(
            .name("XDG-A-1"),
            outputVersion: RawVersion(4),
            xdgOutputVersion: RawVersion(3)
        )
        _ = state.applyCoreEvent(.name("WL-A-1"), version: RawVersion(4))
        _ = state.applyXDGOutputEvent(
            .name("XDG-B-1"),
            outputVersion: RawVersion(4),
            xdgOutputVersion: RawVersion(3)
        )
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 11), version: RawVersion(4))

        #expect(snapshot.name == "WL-A-1")
    }

    @Test
    func emptyWLOutputNameFallsBackToLaterXDGName() {
        var state = RawOutputState()

        _ = state.applyCoreEvent(.name(""), version: RawVersion(4))
        _ = state.applyXDGOutputEvent(
            .name("XDG-A-1"),
            outputVersion: RawVersion(4),
            xdgOutputVersion: RawVersion(3)
        )
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 12), version: RawVersion(4))

        #expect(snapshot.name == "XDG-A-1")
    }

    @Test
    func emptyWLOutputNameRevealsExistingXDGName() {
        var state = RawOutputState()

        _ = state.applyXDGOutputEvent(
            .name("XDG-A-1"),
            outputVersion: RawVersion(4),
            xdgOutputVersion: RawVersion(3)
        )
        _ = state.applyCoreEvent(.name("WL-A-1"), version: RawVersion(4))
        _ = state.applyCoreEvent(.name(""), version: RawVersion(4))
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 13), version: RawVersion(4))

        #expect(snapshot.name == "XDG-A-1")
    }

    @Test
    func emptyWLOutputDescriptionFallsBackToLaterXDGDescription() {
        var state = RawOutputState()

        _ = state.applyCoreEvent(.description(""), version: RawVersion(4))
        _ = state.applyXDGOutputEvent(
            .description("XDG fallback"),
            outputVersion: RawVersion(4),
            xdgOutputVersion: RawVersion(3)
        )
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 14), version: RawVersion(4))

        #expect(snapshot.description == "XDG fallback")
    }

    @Test
    func emptyWLOutputDescriptionRevealsExistingXDGDescription() {
        var state = RawOutputState()

        _ = state.applyXDGOutputEvent(
            .description("XDG fallback"),
            outputVersion: RawVersion(4),
            xdgOutputVersion: RawVersion(3)
        )
        _ = state.applyCoreEvent(
            .description("wl_output description"),
            version: RawVersion(4)
        )
        _ = state.applyCoreEvent(.description(""), version: RawVersion(4))
        let snapshot = state.snapshot(id: RawOutputID(rawValue: 15), version: RawVersion(4))

        #expect(snapshot.description == "XDG fallback")
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

    private func rawMode(
        width: Int32,
        height: Int32,
        flags: UInt32 = 1,
        refreshMilliHertz: Int32 = 60_000
    ) -> RawOutputMode {
        RawOutputMode(
            flags: flags,
            width: width,
            height: height,
            refreshMilliHertz: refreshMilliHertz
        )
    }
}
