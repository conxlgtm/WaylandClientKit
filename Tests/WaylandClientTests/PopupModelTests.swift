import Testing

@testable import WaylandClient

@Suite
struct PopupModelTests {
    private let popupID = PopupID(rawValue: 4)
    private let parentWindowID = WindowID(rawValue: 2)
    private let lifecycleEvent = PopupLifecycleEvent(
        popup: PopupID(rawValue: 4),
        parentWindowID: WindowID(rawValue: 2)
    )

    @Test
    func configureAfterInitialCommitActivatesPopupAndPublishesRedraw() throws {
        var model = try waitingModel()

        let effects = try model.reduce(.configureReceived(configure(serial: 9)))

        #expect(effects == [.ackConfigure(9), .publishRedrawRequested(lifecycleEvent)])
        #expect(model.currentPlacement == configure(serial: 9).placement)
        #expect(model.redraw.hasOutstandingRedrawRequest)
    }

    @Test
    func configureBeforeInitialCommitIsRejected() {
        var model = popupModel()

        #expect(
            throws: ClientError.window(
                parentWindowID,
                .invalidLifecycleTransition(.mapBeforeInitialConfigure)
            )
        ) {
            _ = try model.reduce(.configureReceived(configure(serial: 1)))
        }
    }

    @Test
    func redrawBeforeConfigureIsRejected() throws {
        var model = try waitingModel()

        #expect(
            throws: ClientError.window(
                parentWindowID,
                .invalidLifecycleTransition(.mapBeforeInitialConfigure)
            )
        ) {
            _ = try model.reduce(.redrawRequestConsumed(bufferAvailable: true))
        }
    }

    @Test
    func contentInvalidatedBeforeConfigureDoesNotPublishRedraw() throws {
        var model = try waitingModel()

        #expect(try model.reduce(.contentInvalidated(bufferAvailable: true)).isEmpty)
        #expect(!model.redraw.isDirty)
    }

    @Test
    func explicitCloseClearsRedrawAndPresentationState() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        let effects = try model.reduce(.explicitClose)

        #expect(
            effects == [
                .cancelFrameCallback,
                .retireSwapchain,
                .destroyRoleObjects,
                .publishClosed(lifecycleEvent),
            ]
        )
        #expect(model.isDestroyed)
        #expect(model.presentation == .idle)
        #expect(!model.redraw.isDirty)
        #expect(request.generation == 1)
    }

    @Test
    func compositorDismissalPublishesDismissedBeforeClosed() throws {
        var model = try activeModel()

        let effects = try model.reduce(.compositorDismissed)

        #expect(
            effects == [
                .cancelFrameCallback,
                .retireSwapchain,
                .destroyRoleObjects,
                .publishDismissed(lifecycleEvent),
                .publishClosed(lifecycleEvent),
            ]
        )
        #expect(model.isDestroyed)
    }

    @Test
    func presentationSucceededRejectsStaleGeneration() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(
            throws: ClientError.window(
                parentWindowID,
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
    }

    @Test
    func presentationBlockedByBufferReturnsToWaitingState() throws {
        var (model, _) = try activeModelWithStartedPresentation()

        #expect(try model.reduce(.presentationBlockedByBuffer).isEmpty)
        #expect(model.presentation == .idle)
        #expect(model.redraw.isWaitingForBuffer)
        #expect(
            try model.reduce(.bufferBecameAvailable(bufferAvailable: true))
                == [.publishRedrawRequested(lifecycleEvent)]
        )
    }

    @Test
    func drawFailureLeavesPresentationIdle() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(
            throws: ClientError.window(
                parentWindowID,
                .presentationFailed(.drawFailed("failed"))
            )
        ) {
            _ = try model.reduce(
                .presentationFailed(generation: request.generation, .drawFailed("failed"))
            )
        }
        #expect(model.presentation == .idle)
    }

    private func popupModel() -> PopupModel {
        PopupModel(
            id: popupID,
            parentWindowID: parentWindowID,
            fallbackSize: PositiveLogicalSize(
                width: PositiveInt32(unchecked: 80),
                height: PositiveInt32(unchecked: 40)
            )
        )
    }

    private func waitingModel() throws -> PopupModel {
        var model = popupModel()
        #expect(try model.reduce(.initialCommitSent).isEmpty)
        return model
    }

    private func activeModel() throws -> PopupModel {
        var model = try waitingModel()
        _ = try model.reduce(.configureReceived(configure(serial: 1)))
        return model
    }

    private func activeModelWithStartedPresentation() throws
        -> (PopupModel, PopupPresentationRequest)
    {
        var model = try activeModel()
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailable: true))
        let request = try #require(presentationRequest(from: effects))
        _ = try model.reduce(.presentationStarted(generation: request.generation))
        return (model, request)
    }

    private func configure(serial: UInt32) -> PopupConfigureSequence {
        PopupConfigureSequence(
            serial: serial,
            placement: PopupPlacement(
                origin: LogicalOffset(x: 10, y: 20),
                size: PositiveLogicalSize(
                    width: PositiveInt32(unchecked: 100),
                    height: PositiveInt32(unchecked: 50)
                )
            )
        )
    }

    private func presentationRequest(
        from effects: [PopupEffect]
    ) -> PopupPresentationRequest? {
        for effect in effects {
            if case .performSoftwarePresent(let request) = effect {
                return request
            }
        }

        return nil
    }
}
