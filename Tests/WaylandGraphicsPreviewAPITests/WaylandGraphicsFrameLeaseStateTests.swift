import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsFrameLeaseStateTests {
    @Test
    func nextFrameRejectsSecondActiveLease() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()

        let leaseID = try leaseState.issueLease()

        #expect(leaseID == 1)
        #expect(throws: WaylandGraphicsError.frameLeaseActive) {
            try leaseState.issueLease()
        }
    }

    @Test
    func cancelAllowsNextFrame() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()

        let leaseID = try leaseState.issueLease()
        leaseState.cancel(leaseID: leaseID)

        #expect(try leaseState.issueLease() == 2)
    }

    @Test
    func doubleSubmitConsumesLeaseOnce() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()

        #expect(
            try leaseState.prepareSubmission(leaseID: leaseID) == .show
        )
        #expect(throws: WaylandGraphicsError.frameLeaseConsumed) {
            try leaseState.prepareSubmission(leaseID: leaseID)
        }
    }

    @Test
    func consumedLeaseReportsConsumedBeforeMetadataValidation() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()
        _ = try leaseState.prepareSubmission(leaseID: leaseID)

        #expect(throws: WaylandGraphicsError.frameLeaseConsumed) {
            try leaseState.prepareSubmission(leaseID: leaseID)
        }
    }

    @Test
    func wrongLeaseReportsConsumedBeforeMetadataValidation() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        _ = try leaseState.issueLease()

        #expect(throws: WaylandGraphicsError.frameLeaseConsumed) {
            try leaseState.prepareSubmission(leaseID: 999)
        }
    }

    @Test
    func submissionInFlightRejectsNewLease() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()

        _ = try leaseState.prepareSubmission(leaseID: leaseID)

        #expect(throws: WaylandGraphicsError.frameLeaseActive) {
            try leaseState.issueLease()
        }
    }

    @Test
    func submitAfterCloseFailsWithoutDrawing() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()

        leaseState.close()

        #expect(throws: WaylandGraphicsError.backingClosed) {
            try leaseState.prepareSubmission(leaseID: leaseID)
        }
    }

    @Test
    func secondSubmittedFrameUsesRedrawNotShow() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()

        let firstLeaseID = try leaseState.issueLease()
        #expect(
            try leaseState.prepareSubmission(leaseID: firstLeaseID)
                == .show
        )
        try leaseState.finishSubmission()

        let secondLeaseID = try leaseState.issueLease()
        #expect(
            try leaseState.prepareSubmission(leaseID: secondLeaseID)
                == .redraw
        )
    }

    @Test
    func closedWindowDisplayFailuresMapToTypedPreviewError() {
        let windowID = WindowID(rawValue: 42)

        #expect(
            WaylandGraphicsErrorMapper.mapWindowLifecycleError(
                ClientError.display(.unknownWindow(windowID)),
                windowID: windowID
            ) == .windowClosed
        )
        #expect(
            WaylandGraphicsErrorMapper.mapWindowLifecycleError(
                ClientError.window(
                    windowID,
                    .invalidLifecycleTransition(.presentAfterDestroyed)
                ),
                windowID: windowID
            ) == .windowClosed
        )
    }
}
