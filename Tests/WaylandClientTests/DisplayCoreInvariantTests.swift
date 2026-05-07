import Testing

@testable import WaylandClient

@Suite
struct DisplayCoreInvariantTests {
    @Test
    func emptySurfaceStoreSatisfiesInvariants() throws {
        let core = DisplayCore(eventHub: DisplayEventHub())

        try core.checkInvariantsForTesting()
    }
}
