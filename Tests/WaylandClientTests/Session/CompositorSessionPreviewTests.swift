import Testing

@testable import WaylandClient
@testable import WaylandRaw

@Suite
struct CompositorSessionPreviewTests {
    @Test
    func rawSessionEventsMapToPublicPreviewEvents() {
        #expect(
            CompositorSessionEvent(.created(RawCompositorSessionID("session-1")))
                == .created(CompositorSessionID(unchecked: "session-1"))
        )
        #expect(CompositorSessionEvent(.restored) == .restored)
        #expect(CompositorSessionEvent(.replaced) == .replaced)
    }

    @Test
    func eventSnapshotPreservesProtocolFacts() {
        let sessionID = CompositorSessionID(unchecked: "session-1")
        let events: [CompositorSessionEvent] = [
            .created(sessionID),
            .restored,
            .replaced,
        ]

        let snapshot = CompositorSessionEventSnapshot(events: events)

        #expect(snapshot.events == events)
    }

    @Test
    func invalidExistingSessionIDsAreRejected() {
        #expect(throws: ClientError.display(.invalidCompositorSessionID)) {
            _ = try CompositorSessionID("")
        }
        #expect(throws: ClientError.display(.invalidCompositorSessionID)) {
            _ = try CompositorSessionID("session\0id")
        }
    }

    @Test
    func sessionReasonsMapToRawProtocolReasons() {
        #expect(CompositorSessionReason.launch.rawReason == .launch)
        #expect(CompositorSessionReason.recover.rawReason == .recover)
        #expect(CompositorSessionReason.sessionRestore.rawReason == .sessionRestore)
    }
}
