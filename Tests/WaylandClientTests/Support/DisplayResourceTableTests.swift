import Testing

@testable import WaylandClient

@Suite
struct DisplayResourceTableTests {
    @Test
    func insertGetAndRemoveUseStableIDs() throws {
        var table = DisplayResourceTable<WindowID, String>()
        let id = WindowID(rawValue: 3)

        try table.insert("window", id: id)

        #expect(table.get(id) == "window")
        #expect(table.remove(id) == "window")
        #expect(table.get(id) == nil)
    }

    @Test
    func duplicateInsertIsRejected() throws {
        var table = DisplayResourceTable<DataOfferID, String>()
        let id = DataOfferID(rawValue: 4)

        try table.insert("first", id: id)

        #expect(throws: DisplayResourceTableError<DataOfferID>.duplicateID(id)) {
            try table.insert("second", id: id)
        }
        #expect(table.get(id) == "first")
    }

    @Test
    func removeAllDrainsResources() throws {
        var table = DisplayResourceTable<PopupID, String>()

        try table.insert("first", id: PopupID(rawValue: 1))
        try table.insert("second", id: PopupID(rawValue: 2))

        let removed = table.removeAll().sorted()

        #expect(removed == ["first", "second"])
        #expect(table.isEmpty)
    }

    @Test
    func lookupVocabularyDistinguishesFoundUnknownAndClosed() throws {
        var table = DisplayResourceTable<WindowID, String>()
        let id = WindowID(rawValue: 5)

        try table.insert("window", id: id)

        guard case .found("window") = table.lookup(id) else {
            Issue.record("expected found lookup result")
            return
        }
        guard case .unknown = table.lookup(WindowID(rawValue: 6)) else {
            Issue.record("expected unknown lookup result")
            return
        }
        guard case .closed = table.lookup(id, closed: true) else {
            Issue.record("expected closed lookup result")
            return
        }
    }
}
