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
            try leaseState.prepareSubmission(leaseID: firstLeaseID) == .show
        )

        leaseState.failSubmission()

        #expect(try leaseState.issueLease() == 2)
    }

    @Test
    func submissionFailureDoesNotMarkFirstFrameSubmitted() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let firstLeaseID = try leaseState.issueLease()

        #expect(
            try leaseState.prepareSubmission(leaseID: firstLeaseID) == .show
        )

        leaseState.failSubmission()

        let retryLeaseID = try leaseState.issueLease()
        #expect(
            try leaseState.prepareSubmission(leaseID: retryLeaseID) == .show
        )
    }

    @Test
    func submissionFailureAfterSubmittedFrameKeepsRedrawSequencing() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let firstLeaseID = try leaseState.issueLease()

        _ = try leaseState.prepareSubmission(leaseID: firstLeaseID)
        try leaseState.finishSubmission()

        let secondLeaseID = try leaseState.issueLease()
        #expect(
            try leaseState.prepareSubmission(leaseID: secondLeaseID) == .redraw
        )

        leaseState.failSubmission()

        let retryLeaseID = try leaseState.issueLease()
        #expect(
            try leaseState.prepareSubmission(leaseID: retryLeaseID) == .redraw
        )
    }

    @Test
    func closingDuringSubmittingRemainsClosedAfterFailureCleanup() throws {
        var leaseState = WaylandGraphicsFrameLeaseState()
        let leaseID = try leaseState.issueLease()

        _ = try leaseState.prepareSubmission(leaseID: leaseID)
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
    func submitSoftwarePreservesCallerDrawErrorCause() throws {
        let original = InjectedDrawFailure()
        let wrapped = WindowSoftwareDrawFailure(underlying: original)

        let extracted = try #require(
            WaylandGraphicsErrorMapper.callerDrawError(from: wrapped)
        )

        #expect(extracted is InjectedDrawFailure)
    }

    @Test
    func submitSoftwareRethrowsCallerDrawError() async throws {
        let window = try FakeManagedGraphicsWindow(showDrawFailures: 1)
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .softwareFallback(
                capabilities: softwareOnlySurfaceCapabilities(),
                reason: .forcedSoftware
            )
        )
        let lease = try await storage.nextFrame()

        do {
            _ = try await lease.submitSoftware { _ in
                _ = ()
            }
            Issue.record("expected caller draw failure")
        } catch is InjectedDrawFailure {
            #expect(await window.operations() == [.show])
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test
    func submitSoftwareDrawErrorAllowsRetryAsShow() async throws {
        let window = try FakeManagedGraphicsWindow(showDrawFailures: 1)
        let storage = WaylandGraphicsWindowBackingStorage(
            window: window,
            runtimePath: .softwareFallback(
                capabilities: softwareOnlySurfaceCapabilities(),
                reason: .forcedSoftware
            )
        )
        let failedLease = try await storage.nextFrame()

        do {
            _ = try await failedLease.submitSoftware { _ in
                _ = ()
            }
            Issue.record("expected caller draw failure")
        } catch is InjectedDrawFailure {
            let retryLease = try await storage.nextFrame()
            let result = try await retryLease.submitSoftware { _ in
                _ = ()
            }

            #expect(result.operation == .show)
            #expect(await window.operations() == [.show, .show])
        } catch {
            Issue.record("unexpected error: \(error)")
        }
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

private actor FakeManagedGraphicsWindow: WaylandGraphicsManagedWindow {
    nonisolated let id = WindowID(rawValue: 700)

    private let geometryValue: SurfaceGeometry
    private var remainingShowDrawFailures: Int
    private var recordedOperations: [WaylandGraphicsSubmissionOperation] = []

    init(showDrawFailures: Int) throws {
        geometryValue = try testGraphicsSurfaceGeometry()
        remainingShowDrawFailures = showDrawFailures
    }

    var geometry: SurfaceGeometry {
        get async throws {
            geometryValue
        }
    }

    var isClosed: Bool {
        get async throws {
            false
        }
    }

    func show(
        timeoutMilliseconds _: Int32,
        metadata _: SurfaceCommitMetadata,
        requestPresentationFeedback _: Bool,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        _ = draw
        recordedOperations.append(.show)
        if remainingShowDrawFailures > 0 {
            remainingShowDrawFailures -= 1
            throw WindowSoftwareDrawFailure(underlying: InjectedDrawFailure())
        }
    }

    func redraw(
        metadata _: SurfaceCommitMetadata,
        requestPresentationFeedback _: Bool,
        _ draw: sending @Sendable (borrowing SoftwareFrame) throws -> Void
    ) async throws {
        _ = draw
        recordedOperations.append(.redraw)
    }

    func close() async {
        _ = ()
    }

    func operations() -> [WaylandGraphicsSubmissionOperation] {
        recordedOperations
    }
}

private struct InjectedDrawFailure: Error, Sendable {}
