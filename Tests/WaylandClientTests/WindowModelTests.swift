import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct WindowModelTests {
    private let windowID = WindowID(rawValue: 42)

    @Test
    func initialConfigureResolvesUnspecifiedDimensionFromFallback() throws {
        var model = try configuredModelReadyForConfigure()

        let effects = try model.reduce(
            .configureReceived(configure(width: 0, height: 720, serial: 9))
        )

        #expect(effects == [.ackConfigure(9), .publishRedrawRequested(windowID)])
        #expect(
            model.currentConfiguration?.size
                == PositiveTopLevelSize(
                    width: PositiveInt32(unchecked: 640),
                    height: PositiveInt32(unchecked: 720)
                )
        )
    }

    @Test
    func laterConfigureResolvesUnspecifiedDimensionFromPreviousSize() throws {
        var model = try configuredModelReadyForConfigure()

        _ = try model.reduce(.configureReceived(configure(width: 800, height: 600, serial: 1)))
        let presentationEffects = try model.reduce(.redrawRequestConsumed(bufferAvailable: true))
        let request = try presentationRequest(from: presentationEffects)
        _ = try model.reduce(.presentationStarted(generation: request.generation))
        _ = try model.reduce(.presentationSucceeded(generation: 1, bufferAvailable: true))
        _ = try model.reduce(.frameBecameReady(bufferAvailable: true))

        let effects = try model.reduce(
            .configureReceived(configure(width: 0, height: 720, serial: 2))
        )

        #expect(effects == [.ackConfigure(2), .publishRedrawRequested(windowID)])
        #expect(
            model.currentConfiguration?.size
                == PositiveTopLevelSize(
                    width: PositiveInt32(unchecked: 800),
                    height: PositiveInt32(unchecked: 720)
                )
        )
    }

    @Test
    func configureReceivedWhilePresentationActiveKeepsActiveSubstate() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        let effects = try model.reduce(
            .configureReceived(configure(width: 1_024, height: 768, serial: 7))
        )

        #expect(effects == [.ackConfigure(7), .publishRedrawRequested(windowID)])
        #expect(model.presentation == .drawing(generation: request.generation))
        #expect(model.redraw.hasOutstandingRedrawRequest)
        #expect(
            model.currentConfiguration?.size
                == PositiveTopLevelSize(
                    width: PositiveInt32(unchecked: 1_024),
                    height: PositiveInt32(unchecked: 768)
                )
        )
    }

    @Test
    func negativeConfigureDimensionIsAWindowProtocolError() throws {
        var model = try configuredModelReadyForConfigure()

        #expect(
            throws: ClientError.window(
                windowID,
                .invalidConfigure(.negativeSuggestedDimension(width: -1, height: 480))
            )
        ) {
            _ = try model.reduce(.configureReceived(configure(width: -1, height: 480)))
        }
    }

    @Test
    func configureReceivedBeforeInitialCommitIsRejected() throws {
        var model = WindowModel(id: windowID, fallbackSize: .default)
        _ = try model.reduce(.roleObjectsCreated)

        #expect(
            throws: ClientError.window(
                windowID,
                .invalidLifecycleTransition(.mapBeforeInitialConfigure)
            )
        ) {
            _ = try model.reduce(.configureReceived(configure(width: 640, height: 480)))
        }
    }

    @Test
    func requestOnlyClosePublishesRequestWithoutDestroyingActiveState() throws {
        var model = try activePublishedModel()

        let effects = try model.reduce(.compositorCloseRequested(policy: .requestOnly))

        #expect(effects == [.publishCloseRequested(windowID)])
        #expect(model.closeRequest == .requested)
        #expect(model.currentConfiguration != nil)
        #expect(!model.isClosed)
    }

    @Test
    func requestOnlyCloseBeforeInitialConfigurePublishesRequestWithoutDestroying() throws {
        var model = try configuredModelReadyForConfigure()

        let effects = try model.reduce(.compositorCloseRequested(policy: .requestOnly))

        #expect(effects == [.publishCloseRequested(windowID)])
        #expect(model.closeRequest == .requested)
        #expect(model.currentConfiguration == nil)
        #expect(!model.isClosed)
    }

    @Test
    func requestOnlyCloseBeforeInitialConfigureCarriesRequestIntoActiveState() throws {
        var model = try configuredModelReadyForConfigure()

        _ = try model.reduce(.compositorCloseRequested(policy: .requestOnly))
        #expect(try model.reduce(.compositorCloseRequested(policy: .requestOnly)).isEmpty)

        let effects = try model.reduce(
            .configureReceived(configure(width: 800, height: 600, serial: 8))
        )

        #expect(effects == [.ackConfigure(8), .publishRedrawRequested(windowID)])
        #expect(model.closeRequest == .requested)
        #expect(model.currentConfiguration != nil)
        #expect(!model.isClosed)
    }

    @Test
    func repeatedRequestOnlyCloseDoesNotRepublishRequest() throws {
        var model = try activePublishedModel()

        _ = try model.reduce(.compositorCloseRequested(policy: .requestOnly))

        #expect(try model.reduce(.compositorCloseRequested(policy: .requestOnly)).isEmpty)
    }

    @Test
    func autoClosePublishesOrderedTeardownEffectsOnce() throws {
        var model = try activePublishedModel()

        let effects = try model.reduce(.compositorCloseRequested(policy: .autoClose))

        #expect(
            effects == [
                .publishCloseRequested(windowID),
                .cancelFrameCallback,
                .retireSwapchain,
                .destroyRoleObjects,
                .destroySurface,
                .publishClosed(windowID),
            ]
        )
        #expect(model.isDestroyed)
        #expect(model.publication == .closedPublished(windowID))
    }

    @Test
    func explicitCloseClearsRedrawAndPresentationState() throws {
        var model = try activePublishedModel()

        _ = try model.reduce(.explicitClose)

        #expect(model.isDestroyed)
        #expect(model.presentation == .idle)
        #expect(!model.redraw.isDirty)
    }

    @Test
    func transientStateResetAfterExplicitCloseIsNoOp() throws {
        var model = try activePublishedModel()

        _ = try model.reduce(.explicitClose)

        #expect(try model.reduce(.transientStateReset).isEmpty)
        #expect(model.presentation == .idle)
        #expect(!model.redraw.isDirty)
        #expect(model.isDestroyed)
    }

    @Test
    func contentInvalidatedAfterExplicitCloseDoesNotPublishRedraw() throws {
        var model = try activePublishedModel()

        _ = try model.reduce(.explicitClose)

        #expect(try model.reduce(.contentInvalidated(bufferAvailable: true)).isEmpty)
        #expect(!model.redraw.isDirty)
    }

    @Test
    func frameReadyAfterExplicitCloseDoesNotPublishRedraw() throws {
        var model = try activePublishedModel()

        _ = try model.reduce(.explicitClose)

        #expect(try model.reduce(.frameBecameReady(bufferAvailable: true)).isEmpty)
        #expect(!model.redraw.isDirty)
    }

    @Test
    func bufferAvailableAfterExplicitCloseDoesNotPublishRedraw() throws {
        var (model, _) = try activeModelWithStartedPresentation()
        _ = try model.reduce(.presentationBlockedByBuffer)

        _ = try model.reduce(.explicitClose)

        #expect(try model.reduce(.bufferBecameAvailable(bufferAvailable: true)).isEmpty)
        #expect(!model.redraw.isDirty)
    }
}

extension WindowModelTests {
    @Test
    func redrawRequestConsumedProducesPresentationEffect() throws {
        var model = try activePublishedModel()

        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailable: true))
        let request = PresentationRequest(
            generation: 1,
            configuration: try #require(model.currentConfiguration)
        )

        #expect(effects == [.performSoftwarePresent(request)])
    }

    @Test
    func blockedPresentationReturnsToIdleAndWaitsForBuffer() throws {
        var (model, _) = try activeModelWithStartedPresentation()

        #expect(try model.reduce(.presentationBlockedByBuffer).isEmpty)
        #expect(model.presentation == .idle)
        #expect(model.redraw.isWaitingForBuffer)
        #expect(
            try model.reduce(.bufferBecameAvailable(bufferAvailable: true))
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
                    bufferAvailable: true
                )
            )
        }
        #expect(model.presentation == .drawing(generation: request.generation))
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
                    .drawFailed("stale")
                )
            )
        }
        #expect(model.presentation == .drawing(generation: request.generation))
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
                .presentationFailed(.drawFailed("allocation failed"))
            )
        ) {
            _ = try model.reduce(
                .presentationFailed(
                    generation: request.generation,
                    .drawFailed("allocation failed")
                )
            )
        }
        #expect(model.presentation == .idle)
    }

    @Test
    func redrawAfterPresentationFailureDoesNotReportNestedPresentation() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(throws: ClientError.window(windowID, .presentationFailed(.drawFailed("boom")))) {
            _ = try model.reduce(
                .presentationFailed(generation: request.generation, .drawFailed("boom"))
            )
        }

        #expect(
            try model.reduce(.contentInvalidated(bufferAvailable: true))
                == [.publishRedrawRequested(windowID)]
        )
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailable: true))

        #expect(try presentationRequest(from: effects).generation == request.generation + 1)
    }
}

extension WindowModelTests {
    private func configuredModelReadyForConfigure() throws -> WindowModel {
        var model = WindowModel(id: windowID, fallbackSize: .default)
        _ = try model.reduce(.roleObjectsCreated)
        _ = try model.reduce(.initialCommitSent)
        return model
    }

    private func activePublishedModel() throws -> WindowModel {
        var model = try configuredModelReadyForConfigure()
        model.markPublished()
        _ = try model.reduce(.configureReceived(configure(width: 800, height: 600, serial: 1)))
        return model
    }

    private func activeModelWithStartedPresentation() throws -> (
        model: WindowModel,
        request: PresentationRequest
    ) {
        var model = try activePublishedModel()
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailable: true))
        let request = try presentationRequest(from: effects)
        _ = try model.reduce(.presentationStarted(generation: request.generation))
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
    ) -> XDGConfigureSequence {
        XDGConfigureSequence(
            serial: serial,
            topLevel: XDGTopLevelConfigureSuggestion(
                size: TopLevelSize(width: width, height: height)
            )
        )
    }
}
