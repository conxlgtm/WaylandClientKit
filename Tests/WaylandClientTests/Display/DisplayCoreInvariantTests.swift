import Testing

@testable import WaylandClient

@Suite
struct DisplayCoreInvariantTests {
    @Test
    func emptySurfaceStoreSatisfiesInvariants() throws {
        let core = DisplayCore(eventHub: DisplayEventHub())

        try core.checkInvariantsForTesting()
    }

    @Test
    func repeatedFatalCleanupCallsAreIdempotent() async throws {
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        let windowID = WindowID(rawValue: 7)
        let popupID = PopupID(rawValue: 9)
        let error = WaylandDisplayError.internalInvariantViolation(
            .message("fatal cleanup regression")
        )
        var iterator = hub.displayEvents().makeAsyncIterator()

        core.fail(error)
        core.fail(error)
        core.close()
        core.closeWindow(windowID)
        core.closePopup(popupID)

        try core.checkInvariantsForTesting()
        await expectDisplayFailure(error, from: &iterator)
    }

    @Test
    func deferredFatalCleanupSuppressesOrderlyClosePaths() async throws {
        let hub = DisplayEventHub()
        let core = DisplayCore(eventHub: hub)
        let windowID = WindowID(rawValue: 7)
        let popupID = PopupID(rawValue: 9)
        let invariant = InternalInvariantViolation.message("deferred fatal cleanup")
        let error = WaylandDisplayError.internalInvariantViolation(invariant)
        var iterator = hub.displayEvents().makeAsyncIterator()

        core.reportWindowFailure(.internalInvariant(invariant))
        core.closeWindow(windowID)
        core.closePopup(popupID)
        _ = try? core.windowIsClosed(windowID)
        core.fail(error)

        try core.checkInvariantsForTesting()
        await expectDisplayFailure(error, from: &iterator)
    }
}

private func expectDisplayFailure(
    _ expectedError: WaylandDisplayError,
    from iterator: inout DisplayEventsIterator
) async {
    do {
        _ = try await iterator.next()
        Issue.record("Expected display stream failure")
    } catch {
        #expect(error == expectedError)
    }
}
