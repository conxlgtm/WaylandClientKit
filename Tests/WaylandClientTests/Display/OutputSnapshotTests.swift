import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct OutputSnapshotTests {
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
        #expect(snapshot.currentMode?.width == 1_920)
        #expect(snapshot.currentMode?.flags == [.current])
        #expect(snapshot.currentMode?.refreshMilliHertz == 60_000)
        #expect(snapshot.scale == PositiveInt32(unchecked: 2))
        #expect(snapshot.name == "HDMI-A-1")
        #expect(snapshot.description == "Acme Panel")
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
}
