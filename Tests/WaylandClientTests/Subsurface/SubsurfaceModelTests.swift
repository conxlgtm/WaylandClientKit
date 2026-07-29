import Testing

@testable import WaylandClient

@Suite
struct SubsurfaceModelTests {
    @Test
    func initialPresentationCanBeReservedAndCompleted() throws {
        var model = SubsurfaceModel(synchronizationMode: .synchronized)
        let geometry = try geometry(width: 80)
        let request = try startPresentation(in: &model, geometry: geometry)

        #expect(model.isCurrentSoftwarePresentation(request, geometry: geometry))
        #expect(
            try model.reduce(
                .presentationSucceeded(
                    generation: request.generation,
                    bufferAvailability: .available
                )
            ).isEmpty
        )
        #expect(model.presentation == .idle)
        #expect(!model.redraw.isDirty)
    }

    @Test
    func explicitRedrawPublishesOneRootStreamEffect() throws {
        var model = try presentedModel()

        #expect(
            try model.reduce(.contentInvalidated(bufferAvailability: .available))
                == [.publishRedrawRequested]
        )
        #expect(
            try model.reduce(.contentInvalidated(bufferAvailability: .available)).isEmpty
        )
        #expect(model.redraw.isDirty)
        #expect(model.redraw.hasOutstandingRedrawRequest)
    }

    @Test
    func presentationFeedbackFailurePreservesCommittedFramePacing() throws {
        var model = SubsurfaceModel(synchronizationMode: .synchronized)
        let request = try startPresentation(in: &model, geometry: geometry(width: 80))

        #expect(
            try model.reduce(
                .presentationSucceeded(
                    generation: request.generation,
                    bufferAvailability: .available
                )
            ).isEmpty
        )
        #expect(
            try model.reduce(.contentInvalidated(bufferAvailability: .available)).isEmpty
        )
        let stateBeforeFeedbackFailure = model

        #expect(try model.reduce(.presentationFeedbackFailed).isEmpty)
        #expect(model == stateBeforeFeedbackFailure)
        #expect(
            try model.reduce(.frameBecameReady(bufferAvailability: .available))
                == [.publishRedrawRequested]
        )
    }

    @Test
    func scaleChangeDuringPreparationSupersedesWithoutDuplicatePublication() throws {
        var model = SubsurfaceModel(synchronizationMode: .synchronized)
        let originalGeometry = try geometry(width: 80)
        let replacementGeometry = try geometry(width: 96)
        let request = try startPresentation(in: &model, geometry: originalGeometry)

        #expect(try model.reduce(.scaleChanged(bufferAvailability: .available)).isEmpty)
        #expect(!model.isCurrentSoftwarePresentation(request, geometry: replacementGeometry))
        #expect(
            try model.reduce(
                .softwarePresentationSuperseded(
                    generation: request.generation,
                    bufferAvailability: .available
                )
            ) == [.publishRedrawRequested]
        )
        #expect(model.presentation == .idle)
        #expect(model.redraw.isDirty)
    }

    @Test
    func synchronizationModeChangeDuringPreparationSupersedesExactRequest() throws {
        var model = SubsurfaceModel(synchronizationMode: .synchronized)
        let geometry = try geometry(width: 80)
        let request = try startPresentation(in: &model, geometry: geometry)

        #expect(
            try model.reduce(
                .synchronizationModeChanged(
                    .desynchronized,
                    bufferAvailability: .available
                )
            ).isEmpty
        )
        #expect(model.synchronizationMode == .desynchronized)
        #expect(!model.isCurrentSoftwarePresentation(request, geometry: geometry))
        #expect(
            try model.reduce(
                .softwarePresentationSuperseded(
                    generation: request.generation,
                    bufferAvailability: .available
                )
            ) == [.publishRedrawRequested]
        )
    }

    @Test
    func cancellationRepublishesUncommittedGeneration() throws {
        var model = SubsurfaceModel(synchronizationMode: .desynchronized)
        let request = try startPresentation(in: &model, geometry: geometry(width: 80))

        #expect(
            try model.reduce(
                .softwarePresentationSuperseded(
                    generation: request.generation,
                    bufferAvailability: .available
                )
            ) == [.publishRedrawRequested]
        )
        #expect(model.presentation == .idle)
        #expect(model.redraw.isDirty)
    }

    @Test
    func bufferExhaustionDefersBeforePresentationStarts() throws {
        var model = SubsurfaceModel(synchronizationMode: .synchronized)

        #expect(
            try model.reduce(
                .redrawRequestConsumed(
                    geometry: geometry(width: 80),
                    bufferAvailability: .unavailable
                )
            ).isEmpty
        )
        #expect(model.presentation == .idle)
        #expect(model.redraw.isWaitingForBuffer)
        #expect(
            try model.reduce(.bufferBecameAvailable(bufferAvailability: .available))
                == [.publishRedrawRequested]
        )
    }

    @Test(arguments: [SubsurfaceEvent.explicitClose, .parentWindowClosed])
    func closeTransitionsRetireAllRoleResources(event: SubsurfaceEvent) throws {
        var model = SubsurfaceModel(synchronizationMode: .synchronized)
        let request = try startPresentation(in: &model, geometry: geometry(width: 80))

        #expect(
            try model.reduce(event)
                == [.cancelFrameCallback, .retireSwapchain, .destroyRoleObjects]
        )
        #expect(model.lifecycle == .closed)
        #expect(model.presentation == .idle)
        let closedGeometry = try geometry(width: 80)
        #expect(!model.isCurrentSoftwarePresentation(request, geometry: closedGeometry))
        #expect(try model.reduce(event).isEmpty)
    }

    private func presentedModel() throws -> SubsurfaceModel {
        var model = SubsurfaceModel(synchronizationMode: .synchronized)
        let request = try startPresentation(in: &model, geometry: geometry(width: 80))
        _ = try model.reduce(
            .presentationSucceeded(
                generation: request.generation,
                bufferAvailability: .available
            )
        )
        _ = try model.reduce(.frameBecameReady(bufferAvailability: .available))
        return model
    }

    private func startPresentation(
        in model: inout SubsurfaceModel,
        geometry: SurfaceGeometry
    ) throws -> SubsurfacePresentationRequest {
        let effects = try model.reduce(
            .redrawRequestConsumed(
                geometry: geometry,
                bufferAvailability: .available
            )
        )
        let request = try #require(
            effects.compactMap { effect -> SubsurfacePresentationRequest? in
                guard case .performSoftwarePresent(let request) = effect else { return nil }
                return request
            }.first
        )
        #expect(try model.reduce(.presentationStarted(request)).isEmpty)
        return request
    }

    private func geometry(width: Int32) throws -> SurfaceGeometry {
        try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: width, height: 48),
            scale: .one
        )
    }
}
