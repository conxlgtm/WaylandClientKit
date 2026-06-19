import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct WindowModelPresentationTests {  // swiftlint:disable:this type_body_length
    private let windowID = WindowID(rawValue: 42)

    @Test
    func redrawRequestConsumedProducesPresentationEffect() throws {
        var model = try activePublishedModel()

        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))
        let request = PresentationRequest(
            generation: 1,
            configuration: try #require(model.currentConfiguration)
        )

        #expect(effects == [.performSoftwarePresent(request)])
        #expect(model.presentation == .requested(request: request))
    }

    @Test
    func presentationStateTransitionsFromRequestedToDrawingToIdle() throws {
        var model = try activePublishedModel()

        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))
        let request = try presentationRequest(from: effects)

        #expect(model.presentation == .requested(request: request))
        #expect(try model.reduce(.presentationStarted(request)).isEmpty)
        #expect(model.presentation == .drawing(request: request))
        #expect(
            try model.reduce(
                .presentationSucceeded(
                    generation: request.generation,
                    bufferAvailability: .available
                )
            ).isEmpty
        )
        #expect(model.presentation == .idle)
    }

    @Test
    func blockedPresentationReturnsToIdleAndWaitsForBuffer() throws {
        var (model, _) = try activeModelWithStartedPresentation()

        #expect(try model.reduce(.presentationBlockedByBuffer).isEmpty)
        #expect(model.presentation == .idle)
        #expect(model.redraw.isWaitingForBuffer)
        #expect(
            try model.reduce(.bufferBecameAvailable(bufferAvailability: .available))
                == [.publishRedrawRequested(windowID)]
        )
    }

    @Test
    func presentationSucceededRejectsMismatchedGeneration() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(
            throws: ClientError.window(
                windowID,
                .invalidLifecycleTransition(
                    .presentationGenerationMismatch(
                        expected: request.generation,
                        actual: request.generation + 1
                    )
                )
            )
        ) {
            _ = try model.reduce(
                .presentationSucceeded(
                    generation: request.generation + 1,
                    bufferAvailability: .available
                )
            )
        }
        #expect(model.presentation == .drawing(request: request))
    }

    @Test
    func presentationFailedRejectsMismatchedGeneration() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(
            throws: ClientError.window(
                windowID,
                .invalidLifecycleTransition(
                    .presentationGenerationMismatch(
                        expected: request.generation,
                        actual: request.generation + 1
                    )
                )
            )
        ) {
            _ = try model.reduce(
                .presentationFailed(
                    generation: request.generation + 1,
                    .userDraw("stale")
                )
            )
        }
        #expect(model.presentation == .drawing(request: request))
    }

    @Test
    func presentationBlockedRequiresActivePresentation() throws {
        var model = try activePublishedModel()

        #expect(
            throws: ClientError.window(
                windowID,
                .invalidLifecycleTransition(.inactivePresentationCompletion)
            )
        ) {
            _ = try model.reduce(.presentationBlockedByBuffer)
        }
        #expect(model.presentation == .idle)
    }

    @Test
    func presentationSetupFailureReturnsModelToIdle() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(
            throws: ClientError.window(
                windowID,
                .presentationFailed(.userDraw("allocation failed"))
            )
        ) {
            _ = try model.reduce(
                .presentationFailed(
                    generation: request.generation,
                    .userDraw("allocation failed")
                )
            )
        }
        #expect(model.presentation == .idle)
    }

    @Test
    func redrawAfterPresentationFailureDoesNotReportNestedPresentation() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(throws: ClientError.window(windowID, .presentationFailed(.userDraw("boom")))) {
            _ = try model.reduce(
                .presentationFailed(generation: request.generation, .userDraw("boom"))
            )
        }

        #expect(
            try model.reduce(.contentInvalidated(bufferAvailability: .available))
                == [.publishRedrawRequested(windowID)]
        )
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))

        #expect(try presentationRequest(from: effects).generation == request.generation + 1)
    }

    @Test
    func configureDuringPresentationDefersRedrawPublicationUntilFrameReady() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(
            try model.reduce(.configureReceived(configure(width: 1_024, height: 768, serial: 2)))
                == [.ackConfigure(2)]
        )
        #expect(model.presentation == .drawing(request: request))
        #expect(model.redraw.hasOutstandingRedrawRequest)

        #expect(
            try model.reduce(
                .presentationSucceeded(
                    generation: request.generation,
                    bufferAvailability: .available
                )
            ).isEmpty
        )
        #expect(model.presentation == .idle)
        #expect(model.redraw.isDirty)
        #expect(
            try model.reduce(.frameBecameReady(bufferAvailability: .available))
                == [.publishRedrawRequested(windowID)]
        )
    }

    @Test
    func transientResetAfterDeferredRedrawPublishesWhenFrameReady() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(
            try model.reduce(.configureReceived(configure(width: 1_024, height: 768, serial: 2)))
                == [.ackConfigure(2)]
        )
        #expect(model.presentation == .drawing(request: request))

        #expect(try model.reduce(.transientStateReset).isEmpty)
        #expect(model.presentation == .idle)
        #expect(model.redraw.isDirty)
        #expect(
            try model.reduce(.frameBecameReady(bufferAvailability: .available))
                == [.publishRedrawRequested(windowID)]
        )
    }

    @Test
    func presentationStartRequiresIssuedRequest() throws {
        var model = try activePublishedModel()
        let request = PresentationRequest(
            generation: 1,
            configuration: try #require(model.currentConfiguration)
        )

        #expect(
            throws: ClientError.window(
                windowID,
                .invalidLifecycleTransition(.presentWithoutRedrawRequest)
            )
        ) {
            _ = try model.reduce(.presentationStarted(request))
        }
    }

    @Test
    func presentationStartRejectsRequestForDifferentConfiguration() throws {
        var model = try activePublishedModel()
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))
        let issuedRequest = try presentationRequest(from: effects)
        let staleRequest = PresentationRequest(
            generation: issuedRequest.generation,
            configuration: try configure(width: 1_024, height: 768).configuration
        )

        #expect(issuedRequest.summary != staleRequest.summary)
        #expect(
            throws: ClientError.window(
                windowID,
                .invalidLifecycleTransition(
                    .presentationRequestMismatch(
                        .window(
                            expected: issuedRequest.summary,
                            actual: staleRequest.summary
                        )
                    )
                )
            )
        ) {
            _ = try model.reduce(.presentationStarted(staleRequest))
        }
        #expect(model.presentation == .requested(request: issuedRequest))
    }

    @Test
    func transientStateResetClearsRequestedPresentation() throws {
        var model = try activePublishedModel()
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))
        let request = try presentationRequest(from: effects)

        #expect(model.presentation == .requested(request: request))
        #expect(try model.reduce(.transientStateReset).isEmpty)
        #expect(model.presentation == .idle)
    }

    @Test
    func explicitCloseClearsRequestedPresentation() throws {
        var model = try activePublishedModel()
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))
        let request = try presentationRequest(from: effects)

        #expect(model.presentation == .requested(request: request))
        _ = try model.reduce(.explicitClose)
        #expect(model.isDestroyed)
        #expect(model.presentation == .idle)
    }

    @Test
    func publicationIsAWindowLifecycleEvent() throws {
        var model = WindowModel(id: windowID, fallbackSize: .default)

        #expect(
            throws: ClientError.window(
                windowID,
                .invalidLifecycleTransition(
                    .invalidTransition(from: "created", event: "published")
                )
            )
        ) {
            _ = try model.reduce(.published)
        }

        _ = try model.reduce(.roleObjectsCreated)
        #expect(
            throws: ClientError.window(
                windowID,
                .invalidLifecycleTransition(
                    .invalidTransition(from: "roleAssigned", event: "published")
                )
            )
        ) {
            _ = try model.reduce(.published)
        }

        _ = try model.reduce(.initialCommitSent)
        #expect(try model.reduce(.published).isEmpty)
        #expect(model.publication == .published(windowID))
    }

    @Test
    func unpublishedCloseDoesNotPublishLifecycleEvents() throws {
        var model = try configuredModelReadyForConfigure()

        let effects = try model.reduce(.compositorCloseRequested(policy: .autoClose))

        #expect(
            effects == [
                .cancelFrameCallback,
                .retireSwapchain,
                .destroyRoleObjects,
                .destroySurface,
            ]
        )
        #expect(model.publication == .notPublished)
        #expect(model.isDestroyed)
    }
}

extension WindowModelPresentationTests {
    private func configuredModelReadyForConfigure() throws -> WindowModel {
        var model = WindowModel(id: windowID, fallbackSize: .default)
        _ = try model.reduce(.roleObjectsCreated)
        _ = try model.reduce(.initialCommitSent)
        return model
    }

    private func activePublishedModel() throws -> WindowModel {
        var model = try configuredModelReadyForConfigure()
        _ = try model.reduce(.published)
        _ = try model.reduce(.configureReceived(configure(width: 800, height: 600, serial: 1)))
        return model
    }

    private func activeModelWithStartedPresentation() throws -> (
        model: WindowModel,
        request: PresentationRequest
    ) {
        var model = try activePublishedModel()
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))
        let request = try presentationRequest(from: effects)
        _ = try model.reduce(.presentationStarted(request))
        return (model, request)
    }

    private func presentationRequest(from effects: [WindowEffect]) throws -> PresentationRequest {
        guard case .performSoftwarePresent(let request) = try #require(effects.first) else {
            Issue.record("expected presentation effect")
            throw ClientError.window(
                windowID,
                .invalidLifecycleTransition(.presentWithoutRedrawRequest)
            )
        }

        return request
    }

    private func configure(
        width: Int32,
        height: Int32,
        serial: UInt32 = 1
    ) throws -> WindowConfigureEvent {
        try WindowConfigureEvent(
            sequence: XDGConfigureSequence(
                serial: serial,
                topLevel: XDGTopLevelConfigureSuggestion(
                    size: TopLevelSize(width: width, height: height)
                )
            ),
            previousSize: nil,
            fallbackSize: .default
        )
    }
}
