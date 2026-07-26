import Testing
import WaylandRaw

@testable import WaylandClient

extension WindowModelPresentationTests {
    @Test
    func configureDuringSoftwarePreparationSupersedesAndPublishesReplacementImmediately() throws {
        var (model, request) = try activeModelWithStartedPresentation()
        let replacementConfigure = try configure(width: 1_024, height: 768, serial: 2)

        #expect(
            try model.reduce(.configureReceived(replacementConfigure))
                == [.ackConfigure(2)]
        )
        #expect(!model.isCurrentSoftwarePresentation(request))

        #expect(
            try model.reduce(
                .softwarePresentationSuperseded(
                    generation: request.generation,
                    bufferAvailability: .available
                )
            ) == [.publishRedrawRequested(windowID)]
        )
        #expect(model.presentation == .idle)
        #expect(model.currentConfiguration == replacementConfigure.configuration)
        #expect(model.redraw.isDirty)
        #expect(model.redraw.hasOutstandingRedrawRequest)
    }

    @Test
    func supersededSoftwarePresentationRepublishesNewestGenerationExactlyOnce() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(
            try model.reduce(.contentInvalidated(bufferAvailability: .available)).isEmpty
        )
        #expect(model.redraw.generationForCurrentDraw == request.generation + 1)
        #expect(model.redraw.hasOutstandingRedrawRequest)

        #expect(
            try model.reduce(
                .softwarePresentationSuperseded(
                    generation: request.generation,
                    bufferAvailability: .available
                )
            ) == [.publishRedrawRequested(windowID)]
        )
        #expect(model.presentation == .idle)
        #expect(model.redraw.isDirty)
        #expect(model.redraw.generationForCurrentDraw == request.generation + 1)
        #expect(model.redraw.hasOutstandingRedrawRequest)

        #expect(
            try model.reduce(.contentInvalidated(bufferAvailability: .available)).isEmpty
        )
    }

    @Test
    func canceledSoftwarePreparationRepublishesItsUncommittedGeneration() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(!model.redraw.hasOutstandingRedrawRequest)
        #expect(
            try model.reduce(
                .softwarePresentationSuperseded(
                    generation: request.generation,
                    bufferAvailability: .available
                )
            ) == [.publishRedrawRequested(windowID)]
        )
        #expect(model.presentation == .idle)
        #expect(model.redraw.isDirty)
        #expect(model.redraw.generationForCurrentDraw == request.generation)
        #expect(model.redraw.hasOutstandingRedrawRequest)
    }

    @Test
    func supersededSoftwarePresentationWaitsWhenNoBufferIsAvailable() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(
            try model.reduce(.contentInvalidated(bufferAvailability: .unavailable)).isEmpty
        )
        #expect(model.redraw.isWaitingForBuffer)

        #expect(
            try model.reduce(
                .softwarePresentationSuperseded(
                    generation: request.generation,
                    bufferAvailability: .unavailable
                )
            ).isEmpty
        )
        #expect(model.presentation == .idle)
        #expect(model.redraw.isDirty)
        #expect(model.redraw.isWaitingForBuffer)
        #expect(
            try model.reduce(.bufferBecameAvailable(bufferAvailability: .available))
                == [.publishRedrawRequested(windowID)]
        )
    }

    @Test
    func supersededSoftwarePresentationRejectsMismatchedGeneration() throws {
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
                .softwarePresentationSuperseded(
                    generation: request.generation + 1,
                    bufferAvailability: .available
                )
            )
        }
        #expect(model.presentation == .drawing(request: request))
    }

    @Test
    func softwarePresentationCurrencyRequiresActiveRequestConfigurationAndGeneration() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        #expect(model.isCurrentSoftwarePresentation(request))

        _ = try model.reduce(.contentInvalidated(bufferAvailability: .available))
        #expect(!model.isCurrentSoftwarePresentation(request))

        _ = try model.reduce(
            .softwarePresentationSuperseded(
                generation: request.generation,
                bufferAvailability: .available
            )
        )
        #expect(!model.isCurrentSoftwarePresentation(request))
    }

    @Test
    func manyConsecutiveSoftwareSupersessionsDoNotLoseOrDuplicateRedraws() throws {
        var (model, request) = try activeModelWithStartedPresentation()

        for expectedGeneration in 2...101 {
            #expect(
                try model.reduce(
                    .contentInvalidated(bufferAvailability: .available)
                ).isEmpty
            )
            #expect(model.redraw.generationForCurrentDraw == UInt64(expectedGeneration))
            #expect(
                try model.reduce(
                    .softwarePresentationSuperseded(
                        generation: request.generation,
                        bufferAvailability: .available
                    )
                ) == [.publishRedrawRequested(windowID)]
            )
            #expect(model.presentation == .idle)

            let effects = try model.reduce(
                .redrawRequestConsumed(bufferAvailability: .available)
            )
            guard case .performSoftwarePresent(let nextRequest) = try #require(effects.first) else {
                Issue.record("expected replacement software presentation")
                return
            }
            #expect(effects.count == 1)
            _ = try model.reduce(.presentationStarted(nextRequest))
            request = nextRequest
        }
    }
}
