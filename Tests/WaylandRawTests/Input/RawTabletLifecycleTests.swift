import Testing

@testable import WaylandRaw

@Suite
struct RawTabletLifecycleTests {
    @Test
    func tabletRemovedPublishesEventAndDestroysTrackedObjectOnce() throws {
        let fixture = try RawTabletLifecycleFixture()
        let tabletID = RawTabletIdentity(objectID: RawObjectID(0x901))
        let tablet = try RawTablet(
            pointer: unsafe fakePointer(0x901),
            version: 2,
            seatID: fixture.seat.seatID,
            eventSink: fixture.queue,
            proxyAdoption: fixture.proxyAdoption,
            destroy: unsafe fixture.recorder.destroy("tablet"),
            identity: tabletID,
            installListener: false
        ) { identity in
            fixture.seat.handleTabletRemovedForTesting(identity)
        }
        fixture.seat.trackTabletForTesting(tablet)

        tablet.emitRemovedForTesting()

        #expect(fixture.seat.trackedTabletCountForTesting == 0)
        #expect(fixture.recorder.destroyed(named: "tablet") == [0x901])
        #expect(
            fixture.queue.drain().map(\.kind)
                == [.tablet(.tablet(.removed(tabletID)))]
        )

        tablet.emitRemovedForTesting()
        fixture.seat.destroy()

        #expect(fixture.queue.drain().isEmpty)
        #expect(fixture.recorder.destroyed(named: "tablet") == [0x901])
    }

    @Test
    func toolRemovedPublishesEventAndDestroysTrackedObjectOnce() throws {
        let fixture = try RawTabletLifecycleFixture()
        let toolID = RawTabletToolIdentity(objectID: RawObjectID(0xA01))
        let tool = try RawTabletTool(
            pointer: unsafe fakePointer(0xA01),
            version: 2,
            seatID: fixture.seat.seatID,
            eventSink: fixture.queue,
            proxyAdoption: fixture.proxyAdoption,
            destroy: unsafe fixture.recorder.destroy("tool"),
            identity: toolID,
            installListener: false
        ) { identity in
            fixture.seat.handleToolRemovedForTesting(identity)
        }
        fixture.seat.trackToolForTesting(tool)

        tool.emitRemovedForTesting()

        #expect(fixture.seat.trackedToolCountForTesting == 0)
        #expect(fixture.recorder.destroyed(named: "tool") == [0xA01])
        #expect(
            fixture.queue.drain().map(\.kind)
                == [.tablet(.tool(.removed(toolID)))]
        )

        tool.emitRemovedForTesting()
        fixture.seat.destroy()

        #expect(fixture.queue.drain().isEmpty)
        #expect(fixture.recorder.destroyed(named: "tool") == [0xA01])
    }

    @Test
    func padRemovedDestroysTrackedPadAndChildGroupsOnce() throws {
        let fixture = try RawTabletLifecycleFixture()
        let padID = RawTabletPadIdentity(objectID: RawObjectID(0xB01))
        let pad = try RawTabletPad(
            pointer: unsafe fakePointer(0xB01),
            version: 2,
            seatID: fixture.seat.seatID,
            eventSink: fixture.queue,
            proxyAdoption: fixture.proxyAdoption,
            destroy: unsafe fixture.recorder.destroy("pad"),
            groupDestroy: unsafe fixture.recorder.destroy("group"),
            ringDestroy: unsafe fixture.recorder.destroy("ring"),
            stripDestroy: unsafe fixture.recorder.destroy("strip"),
            dialDestroy: unsafe fixture.recorder.destroy("dial"),
            identity: padID,
            installListener: false
        ) { identity in
            fixture.seat.handlePadRemovedForTesting(identity)
        }
        unsafe pad.trackGroupForTesting(unsafe fakePointer(0xB02))
        unsafe pad.emitGroupRingForTesting(unsafe fakePointer(0xB03))
        unsafe pad.emitGroupStripForTesting(unsafe fakePointer(0xB04))
        unsafe pad.emitGroupDialForTesting(unsafe fakePointer(0xB05))
        fixture.seat.trackPadForTesting(pad)

        pad.emitRemovedForTesting()

        #expect(fixture.seat.trackedPadCountForTesting == 0)
        #expect(pad.trackedGroupCountForTesting == 0)
        #expect(pad.trackedRingCountForTesting == 0)
        #expect(pad.trackedStripCountForTesting == 0)
        #expect(pad.trackedDialCountForTesting == 0)
        #expect(fixture.recorder.destroyed(named: "ring") == [0xB03])
        #expect(fixture.recorder.destroyed(named: "strip") == [0xB04])
        #expect(fixture.recorder.destroyed(named: "dial") == [0xB05])
        #expect(fixture.recorder.destroyed(named: "group") == [0xB02])
        #expect(fixture.recorder.destroyed(named: "pad") == [0xB01])
        #expect(
            fixture.queue.drain().map(\.kind)
                == [.tablet(.pad(.removed(padID)))]
        )

        pad.emitRemovedForTesting()
        fixture.seat.destroy()

        #expect(fixture.queue.drain().isEmpty)
        #expect(fixture.recorder.destroyed(named: "ring") == [0xB03])
        #expect(fixture.recorder.destroyed(named: "strip") == [0xB04])
        #expect(fixture.recorder.destroyed(named: "dial") == [0xB05])
        #expect(fixture.recorder.destroyed(named: "group") == [0xB02])
        #expect(fixture.recorder.destroyed(named: "pad") == [0xB01])
    }
}

private final class RawTabletLifecycleFixture {
    let recorder = DestroyRecorder()
    let queue = RawInputEventQueue()
    let proxyAdoption: RawProxyAdoptionContext
    let seat: RawTabletSeat

    init() throws {
        proxyAdoption = RawProxyAdoptionContext(
            eventQueue: RawEventQueue.testingQueueWithoutDestroy(
                opaquePointer: unsafe fakePointer(0xE00)
            )
        )
        seat = RawTabletSeat(
            uncheckedPointer: unsafe fakePointer(0xE01),
            version: 2,
            seatID: RawSeatID(rawValue: 42),
            eventSink: queue,
            proxyAdoption: proxyAdoption,
            destroy: unsafe recorder.destroy("seat")
        )
    }
}

private final class DestroyRecorder {
    private var entries: [(name: String, pointer: UInt)] = []

    func destroy(_ name: String) -> (OpaquePointer) -> Void {
        { [self] pointer in
            entries.append((name, UInt(bitPattern: pointer)))
        }
    }

    func destroyed(named name: String) -> [UInt] {
        entries.compactMap { entry in
            entry.name == name ? entry.pointer : nil
        }
    }
}

private func fakePointer(_ bitPattern: UInt) -> OpaquePointer {
    guard let pointer = unsafe OpaquePointer(bitPattern: bitPattern) else {
        fatalError("invalid test pointer bit pattern: \(bitPattern)")
    }
    return unsafe pointer
}
