import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct CursorRoleRuntimeTests {
    @Test
    func cursorRoleRuntimePublishesCursorCapabilitySnapshot() throws {
        let runtime = try CursorRoleRuntime(surfaceID: RawObjectID(0xC00))

        let snapshot = runtime.capabilitySnapshot

        #expect(snapshot.role == .cursor)
        #expect(snapshot.outputIDs.isEmpty)
        #expect(snapshot.fractionalScale == .integerOnly)
        #expect(snapshot.presentationFeedback == .unavailable)
        #expect(snapshot.dmabuf == .unavailable)
    }

    @Test
    func cursorRoleRuntimeDestroyMarksSurfaceDestroyed() throws {
        var runtime = try CursorRoleRuntime(surfaceID: RawObjectID(0xC00))

        try runtime.destroy()

        let snapshot = runtime.capabilitySnapshot
        #expect(snapshot.role == .cursor)
        #expect(snapshot.outputIDs.isEmpty)
        #expect(snapshot.fractionalScale == .integerOnly)
        #expect(snapshot.presentationFeedback == .unavailable)
        #expect(snapshot.dmabuf == .unavailable)
        #expect(runtime.transactionSnapshot == SurfaceTransactionState().snapshot)
    }
}
