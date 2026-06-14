import Testing

@testable import WaylandRaw

@Suite
struct RawCompositorSessionLifecycleTests {
    @Test
    func managerDestroyIsIdempotent() throws {
        let fixture = try RawCompositorSessionLifecycleFixture()
        let manager = RawCompositorSessionManager(
            uncheckedPointer: try unsafe fakePointer(0xC01),
            version: 1,
            proxyAdoption: fixture.proxyAdoption,
            destroy: unsafe fixture.recorder.destroy("manager")
        )

        manager.destroy()
        manager.destroy()

        #expect(fixture.recorder.destroyed(named: "manager") == [0xC01])
    }

    @Test
    func sessionEventsMapAndStopAfterDestroy() throws {
        let fixture = try RawCompositorSessionLifecycleFixture()
        var events: [RawCompositorSessionEvent] = []
        let session = try RawCompositorSession(
            pointer: try unsafe fakePointer(0xC10),
            version: 1,
            proxyAdoption: fixture.proxyAdoption,
            destroy: unsafe fixture.recorder.destroy("session"),
            toplevelDestroy: unsafe fixture.recorder.destroy("toplevel"),
            installListener: false
        ) { event in
            events.append(event)
        }

        session.emitCreatedForTesting("session-1")
        session.emitRestoredForTesting()
        session.emitReplacedForTesting()

        #expect(events == [.created(RawCompositorSessionID("session-1")), .restored, .replaced])

        session.destroy()
        session.emitCreatedForTesting("late-session")
        session.emitRestoredForTesting()
        session.emitReplacedForTesting()
        session.destroy()

        #expect(events == [.created(RawCompositorSessionID("session-1")), .restored, .replaced])
        #expect(fixture.recorder.destroyed(named: "session") == [0xC10])
    }

    @Test
    func toplevelEventsMapAndStopAfterDestroy() throws {
        let fixture = try RawCompositorSessionLifecycleFixture()
        var events: [RawCompositorToplevelSessionEvent] = []
        let toplevel = try RawCompositorToplevelSession(
            pointer: try unsafe fakePointer(0xC20),
            invariantFailureSink: fixture.proxyAdoption.invariantFailureSink,
            destroy: unsafe fixture.recorder.destroy("toplevel"),
            installListener: false
        ) { event in
            events.append(event)
        }

        toplevel.emitRestoredForTesting()

        #expect(events == [.restored])

        toplevel.destroy()
        toplevel.emitRestoredForTesting()
        toplevel.destroy()

        #expect(events == [.restored])
        #expect(fixture.recorder.destroyed(named: "toplevel") == [0xC20])
    }

    @Test
    func sessionDestroyCleansTrackedToplevelSessionsOnce() throws {
        let fixture = try RawCompositorSessionLifecycleFixture()
        var firstEvents: [RawCompositorToplevelSessionEvent] = []
        var secondEvents: [RawCompositorToplevelSessionEvent] = []
        let session = try RawCompositorSession(
            pointer: try unsafe fakePointer(0xC30),
            version: 1,
            proxyAdoption: fixture.proxyAdoption,
            destroy: unsafe fixture.recorder.destroy("session"),
            toplevelDestroy: unsafe fixture.recorder.destroy("toplevel"),
            installListener: false
        ) { _ in
            Issue.record("unexpected session event")
        }
        let firstToplevel = try RawCompositorToplevelSession(
            pointer: try unsafe fakePointer(0xC31),
            invariantFailureSink: fixture.proxyAdoption.invariantFailureSink,
            destroy: unsafe fixture.recorder.destroy("toplevel"),
            installListener: false
        ) { event in
            firstEvents.append(event)
        }
        let secondToplevel = try RawCompositorToplevelSession(
            pointer: try unsafe fakePointer(0xC32),
            invariantFailureSink: fixture.proxyAdoption.invariantFailureSink,
            destroy: unsafe fixture.recorder.destroy("toplevel"),
            installListener: false
        ) { event in
            secondEvents.append(event)
        }
        session.trackToplevelSessionForTesting(firstToplevel)
        session.trackToplevelSessionForTesting(secondToplevel)

        #expect(session.trackedToplevelSessionCountForTesting == 2)

        session.destroy()
        firstToplevel.emitRestoredForTesting()
        secondToplevel.emitRestoredForTesting()
        session.destroy()

        #expect(session.trackedToplevelSessionCountForTesting == 0)
        #expect(firstEvents.isEmpty)
        #expect(secondEvents.isEmpty)
        #expect(fixture.recorder.destroyed(named: "toplevel") == [0xC31, 0xC32])
        #expect(fixture.recorder.destroyed(named: "session") == [0xC30])
    }
}

private final class RawCompositorSessionLifecycleFixture {
    let recorder = DestroyRecorder()
    let proxyAdoption: RawProxyAdoptionContext

    init() throws {
        proxyAdoption = RawProxyAdoptionContext(
            eventQueue: RawEventQueue.testingQueueWithoutDestroy(
                opaquePointer: try unsafe fakePointer(0xCF0)
            )
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

private enum FakePointerError: Error {
    case invalid(UInt)
}

private func fakePointer(_ bitPattern: UInt) throws -> OpaquePointer {
    guard let pointer = unsafe OpaquePointer(bitPattern: bitPattern) else {
        throw FakePointerError.invalid(bitPattern)
    }
    return unsafe pointer
}
