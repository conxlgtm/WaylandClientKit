import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandGraphicsSubmissionFailureTests {
    @Test
    func submissionFailureClearsSubmittingStateAndAllowsNewLease() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let firstLeaseID = try leaseState.issueLease()

        #expect(
            try leaseState.prepareSubmission(
                leaseID: firstLeaseID,
                frame: .clearColor(.black)
            ) == .show
        )

        leaseState.failSubmission()

        #expect(try leaseState.issueLease() == 2)
    }

    @Test
    func submissionFailureDoesNotMarkFirstFrameSubmitted() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let firstLeaseID = try leaseState.issueLease()

        #expect(
            try leaseState.prepareSubmission(
                leaseID: firstLeaseID,
                frame: .clearColor(.black)
            ) == .show
        )

        leaseState.failSubmission()

        let retryLeaseID = try leaseState.issueLease()
        #expect(
            try leaseState.prepareSubmission(
                leaseID: retryLeaseID,
                frame: .clearColor(.black)
            ) == .show
        )
    }

    @Test
    func submissionFailureAfterSubmittedFrameKeepsRedrawSequencing() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let firstLeaseID = try leaseState.issueLease()

        _ = try leaseState.prepareSubmission(
            leaseID: firstLeaseID,
            frame: .clearColor(.black)
        )
        try leaseState.finishSubmission()

        let secondLeaseID = try leaseState.issueLease()
        #expect(
            try leaseState.prepareSubmission(
                leaseID: secondLeaseID,
                frame: .clearColor(.black)
            ) == .redraw
        )

        leaseState.failSubmission()

        let retryLeaseID = try leaseState.issueLease()
        #expect(
            try leaseState.prepareSubmission(
                leaseID: retryLeaseID,
                frame: .clearColor(.black)
            ) == .redraw
        )
    }

    @Test
    func closingDuringSubmittingRemainsClosedAfterFailureCleanup() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()

        _ = try leaseState.prepareSubmission(
            leaseID: leaseID,
            frame: .clearColor(.black)
        )
        leaseState.close()
        leaseState.failSubmission()

        #expect(throws: WaylandGraphicsError.backingClosed) {
            try leaseState.issueLease()
        }
    }

    @Test
    func redrawLifecycleFailurePreservesTransitionAndWindowID() {
        let windowID = WindowID(rawValue: 42)
        let transition = WindowLifecycleTransitionError.presentWithoutRedrawRequest

        let error = WaylandGraphicsErrorMapper.mapSubmissionError(
            ClientError.window(windowID, .invalidLifecycleTransition(transition)),
            windowID: windowID,
            operation: .redraw,
            stage: .frameSubmission
        )

        #expect(
            error
                == .submissionFailed(
                    .windowLifecycle(
                        windowID: windowID,
                        transition: transition,
                        operation: .redraw,
                        stage: .frameSubmission
                    )
                )
        )
    }

    @Test
    func geometryFailurePreservesClientErrorContext() {
        let windowID = WindowID(rawValue: 43)

        let error = WaylandGraphicsErrorMapper.mapSubmissionError(
            ClientError.display(.presentationTimeUnavailable),
            windowID: windowID,
            operation: nil,
            stage: .frameGeometry
        )

        #expect(
            error
                == .submissionFailed(
                    .display(
                        error: .presentationTimeUnavailable,
                        operation: nil,
                        stage: .frameGeometry
                    )
                )
        )
    }

    @Test
    func unknownSubmissionFailureIncludesOperationStage() {
        let windowID = WindowID(rawValue: 44)

        let error = WaylandGraphicsErrorMapper.mapSubmissionError(
            InjectedUnexpectedSubmissionError(),
            windowID: windowID,
            operation: .show,
            stage: .frameSubmission
        )

        #expect(
            error
                == .submissionFailed(
                    .unexpected(
                        operation: .show,
                        stage: .frameSubmission,
                        description: "injected graphics submission failure"
                    )
                )
        )
    }

    @Test
    func windowLifecycleAndWindowSubmissionFailuresAreDistinct() {
        let windowID = WindowID(rawValue: 45)

        let lifecycleError = WaylandGraphicsErrorMapper.mapSubmissionError(
            ClientError.window(
                windowID,
                .invalidLifecycleTransition(.presentWithoutRedrawRequest)
            ),
            windowID: windowID,
            operation: .redraw,
            stage: .frameSubmission
        )
        let timeoutError = WaylandGraphicsErrorMapper.mapSubmissionError(
            ClientError.window(
                windowID,
                .initialConfigureTimedOut(milliseconds: 5)
            ),
            windowID: windowID,
            operation: .show,
            stage: .frameSubmission
        )

        #expect(lifecycleError != timeoutError)
        #expect(
            timeoutError
                == .submissionFailed(
                    .window(
                        windowID: windowID,
                        error: .initialConfigureTimedOut(milliseconds: 5),
                        operation: .show,
                        stage: .frameSubmission
                    )
                )
        )
    }
}

private struct InjectedUnexpectedSubmissionError: Error, CustomStringConvertible {
    var description: String {
        "injected graphics submission failure"
    }
}
