import Testing

@testable import WaylandClient
@testable import WaylandRaw

@Suite
struct ForeignToplevelPreviewTests {
    @Test
    func collectorPublishesAddUpdateRemoveAndIgnoresLateEvents() throws {
        var idsByIdentifier: [String: ForeignToplevelID] = [:]
        var nextID: UInt64 = 1
        let collector = ForeignToplevelListCollector { identifier in
            guard let identifier else {
                defer { nextID += 1 }
                return ForeignToplevelID(rawValue: nextID)
            }

            if let existing = idsByIdentifier[identifier] {
                return existing
            }

            let id = ForeignToplevelID(rawValue: nextID)
            nextID += 1
            idsByIdentifier[identifier] = id
            return id
        }
        let handle = RawForeignToplevelHandle.testingHandle(
            pointer: try unsafe fakePointer(0xF01)
        )

        collector.handle(.toplevel(handle))
        collector.handle(.handle(handle, .identifier("window-1")))
        collector.handle(.handle(handle, .title("First title")))
        collector.handle(.handle(handle, .appID("example.app")))
        collector.handle(.handle(handle, .done))

        let added = ForeignToplevelSnapshot(
            id: ForeignToplevelID(rawValue: 1),
            protocolIdentifier: "window-1",
            title: "First title",
            appID: "example.app"
        )
        #expect(collector.snapshot().toplevels == [added])
        #expect(collector.snapshot().events == [.added(added)])

        collector.handle(.handle(handle, .title("Updated title")))
        collector.handle(.handle(handle, .done))

        let updated = ForeignToplevelSnapshot(
            id: ForeignToplevelID(rawValue: 1),
            protocolIdentifier: "window-1",
            title: "Updated title",
            appID: "example.app"
        )
        #expect(collector.snapshot().toplevels == [updated])
        #expect(collector.snapshot().events == [.added(added), .updated(updated)])

        collector.handle(.handle(handle, .closed))
        collector.handle(.handle(handle, .title("Late title")))
        collector.handle(.handle(handle, .done))
        collector.handle(.finished)

        #expect(collector.isFinished)
        #expect(collector.snapshot().toplevels.isEmpty)
        #expect(
            collector.snapshot().events == [
                .added(added),
                .updated(updated),
                .removed(ForeignToplevelID(rawValue: 1)),
            ]
        )
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
