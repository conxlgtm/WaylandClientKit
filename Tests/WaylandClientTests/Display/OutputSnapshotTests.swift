import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct OutputSnapshotTests {
    @Test
    func outputTopologySnapshotSortsByStableOutputID() {
        let first = OutputSnapshot(
            id: OutputID(rawValue: 2),
            version: 4,
            geometry: nil,
            logicalGeometry: nil,
            currentMode: nil,
            scale: PositiveInt32(unchecked: 1),
            name: "second",
            description: nil
        )
        let second = OutputSnapshot(
            id: OutputID(rawValue: 1),
            version: 4,
            geometry: nil,
            logicalGeometry: nil,
            currentMode: nil,
            scale: PositiveInt32(unchecked: 1),
            name: "first",
            description: nil
        )

        let topology = OutputTopologySnapshot(outputs: [first, second])

        #expect(topology.outputs.map(\.id) == [OutputID(rawValue: 1), OutputID(rawValue: 2)])
    }

    @Test
    func publicSnapshotCopiesRawOutputMetadata() {
        let raw = RawOutputSnapshot(
            id: RawOutputID(rawValue: 7),
            version: RawVersion(4),
            geometry: RawOutputGeometry(
                x: 10,
                y: 20,
                physicalWidthMillimeters: 600,
                physicalHeightMillimeters: 340,
                subpixel: 1,
                make: "Acme",
                model: "Panel",
                transform: 0
            ),
            logicalGeometry: RawOutputLogicalGeometry(
                x: 1_920,
                y: 0,
                width: 1_280,
                height: 720
            ),
            currentMode: RawOutputMode(
                flags: 1,
                width: 1_920,
                height: 1_080,
                refreshMilliHertz: 60_000
            ),
            scale: 2,
            name: "HDMI-A-1",
            description: "Acme Panel"
        )

        let snapshot = OutputSnapshot(raw)

        #expect(snapshot.id == OutputID(rawValue: 7))
        #expect(snapshot.version == 4)
        #expect(snapshot.geometry?.make == "Acme")
        #expect(snapshot.geometry?.model == "Panel")
        #expect(snapshot.geometry?.subpixel == OutputSubpixelLayout.none)
        #expect(snapshot.geometry?.transform == .normal)
        #expect(snapshot.logicalGeometry?.x == 1_920)
        #expect(snapshot.logicalGeometry?.width == PositiveInt32(unchecked: 1_280))
        #expect(snapshot.logicalGeometry?.height == PositiveInt32(unchecked: 720))
        #expect(snapshot.currentMode?.width == PositiveInt32(unchecked: 1_920))
        #expect(snapshot.currentMode?.height == PositiveInt32(unchecked: 1_080))
        #expect(snapshot.currentMode?.flags == [.current])
        #expect(snapshot.currentMode?.refresh == .milliHertz(PositiveInt32(unchecked: 60_000)))
        #expect(snapshot.scale == PositiveInt32(unchecked: 2))
        #expect(snapshot.name == "HDMI-A-1")
        #expect(snapshot.description == "Acme Panel")
    }

    @Test
    func publicSnapshotDropsCurrentModeWithNonPositiveWidth() {
        let snapshot = OutputSnapshot(rawSnapshot(mode: rawMode(width: 0)))

        #expect(snapshot.currentMode == nil)
    }

    @Test
    func publicSnapshotDropsCurrentModeWithNonPositiveHeight() {
        let snapshot = OutputSnapshot(rawSnapshot(mode: rawMode(height: -1)))

        #expect(snapshot.currentMode == nil)
    }

    @Test
    func publicSnapshotAllowsZeroRefreshAsUnspecified() {
        let snapshot = OutputSnapshot(rawSnapshot(mode: rawMode(refreshMilliHertz: 0)))

        #expect(snapshot.currentMode?.refresh == .unspecified)
    }

    @Test
    func publicSnapshotDropsCurrentModeWithNegativeRefresh() {
        let snapshot = OutputSnapshot(rawSnapshot(mode: rawMode(refreshMilliHertz: -1)))

        #expect(snapshot.currentMode == nil)
    }

    @Test
    func publicSnapshotDropsNonCurrentOutputMode() {
        let snapshot = OutputSnapshot(rawSnapshot(mode: rawMode(flags: 0)))

        #expect(snapshot.currentMode == nil)
    }

    @Test
    func rawCurrentModeValidationRejectsMalformedTransportData() {
        #expect(rawMode(width: -1).isValidCurrentMode == false)
        #expect(rawMode(height: 0).isValidCurrentMode == false)
        #expect(rawMode(refreshMilliHertz: -1).isValidCurrentMode == false)
        #expect(rawMode(flags: 0).isValidCurrentMode == false)
        #expect(rawMode().isValidCurrentMode)
    }

    @Test
    func outputMetadataPreservesUnknownRawValues() {
        #expect(OutputSubpixelLayout(rawValue: 99) == .unrecognized(99))
        #expect(OutputSubpixelLayout.unrecognized(99).rawValue == 99)
        #expect(OutputTransform(rawValue: 99) == .unrecognized(99))
        #expect(OutputTransform.unrecognized(99).rawValue == 99)
    }

    @Test
    func rawOutputEventsMapToDisplayEvents() {
        let raw = RawOutputSnapshot(
            id: RawOutputID(rawValue: 9),
            version: RawVersion(3),
            geometry: nil,
            logicalGeometry: nil,
            currentMode: nil,
            scale: 1,
            name: nil,
            description: nil
        )

        #expect(
            DisplayEvent(.changed(raw))
                == .outputChanged(OutputSnapshot(raw))
        )
        #expect(
            DisplayEvent(.removed(RawOutputID(rawValue: 10)))
                == .outputRemoved(OutputID(rawValue: 10))
        )
    }

    private func rawSnapshot(mode: RawOutputMode?) -> RawOutputSnapshot {
        RawOutputSnapshot(
            id: RawOutputID(rawValue: 7),
            version: RawVersion(4),
            geometry: nil,
            logicalGeometry: nil,
            currentMode: mode,
            scale: 1,
            name: nil,
            description: nil
        )
    }

    private func rawMode(
        flags: UInt32 = 1,
        width: Int32 = 1_920,
        height: Int32 = 1_080,
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
