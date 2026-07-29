import Testing

@testable import WaylandClient

@Suite
struct PopupPreparedPresentationModelTests {
    private let popupID = PopupID(rawValue: 40)
    private let parentWindowID = WindowID(rawValue: 20)

    @Test
    func configureDuringPreparationSupersedesExactRequestAndCoalescesReplacement() throws {
        var model = try activeModel()
        let request = try startPresentation(in: &model)

        let configureEffects = try model.reduce(
            .configureReceived(configure(serial: 2, originX: 99))
        )
        #expect(!model.isCurrentSoftwarePresentation(request))
        #expect(!configureEffects.contains(.publishRedrawRequested(lifecycleEvent)))

        let supersessionEffects = try model.reduce(
            .softwarePresentationSuperseded(
                generation: request.generation,
                bufferAvailability: .available
            )
        )
        #expect(model.presentation == .idle)
        #expect(model.redraw.isDirty)
        #expect(supersessionEffects == [.publishRedrawRequested(lifecycleEvent)])
    }

    @Test
    func explicitRedrawDuringPreparationPublishesOneReplacement() throws {
        var model = try activeModel()
        let request = try startPresentation(in: &model)

        let invalidationEffects = try model.reduce(
            .contentInvalidated(bufferAvailability: .available)
        )
        #expect(!model.isCurrentSoftwarePresentation(request))
        #expect(invalidationEffects.isEmpty)

        let repeatedInvalidationEffects = try model.reduce(
            .contentInvalidated(bufferAvailability: .available)
        )
        #expect(repeatedInvalidationEffects.isEmpty)

        let supersessionEffects = try model.reduce(
            .softwarePresentationSuperseded(
                generation: request.generation,
                bufferAvailability: .available
            )
        )
        #expect(supersessionEffects == [.publishRedrawRequested(lifecycleEvent)])
        #expect(model.redraw.isDirty)
    }

    @Test
    func cancellationWithoutNewContentRepublishesEligibleWork() throws {
        var model = try activeModel()
        let request = try startPresentation(in: &model)

        let effects = try model.reduce(
            .softwarePresentationSuperseded(
                generation: request.generation,
                bufferAvailability: .available
            )
        )

        #expect(effects == [.publishRedrawRequested(lifecycleEvent)])
        #expect(model.presentation == .idle)
        #expect(model.redraw.isDirty)
    }

    @Test
    func dismissalDuringPreparationClosesInsteadOfRepublishing() throws {
        var model = try activeModel()
        let request = try startPresentation(in: &model)

        let effects = try model.reduce(.compositorDismissed)

        #expect(model.isClosed)
        #expect(model.presentation == .idle)
        #expect(effects.contains(.publishDismissed(lifecycleEvent)))
        #expect(effects.contains(.publishClosed(lifecycleEvent)))
        #expect(!model.isCurrentSoftwarePresentation(request))
    }

    private var lifecycleEvent: PopupLifecycleEvent {
        PopupLifecycleEvent(popup: popupID, parentWindowID: parentWindowID)
    }

    private func activeModel() throws -> PopupModel {
        var model = PopupModel(
            id: popupID,
            parentWindowID: parentWindowID,
            fallbackSize: PositiveLogicalSize(
                width: PositiveInt32(unchecked: 80),
                height: PositiveInt32(unchecked: 40)
            )
        )
        _ = try model.reduce(.initialCommitSent)
        _ = try model.reduce(.configureReceived(configure(serial: 1, originX: 10)))
        return model
    }

    private func startPresentation(in model: inout PopupModel) throws -> PopupPresentationRequest {
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))
        let request = try #require(
            effects.compactMap { effect -> PopupPresentationRequest? in
                guard case .performSoftwarePresent(let request) = effect else { return nil }
                return request
            }.first
        )
        _ = try model.reduce(.presentationStarted(request))
        #expect(model.isCurrentSoftwarePresentation(request))
        return request
    }

    private func configure(serial: UInt32, originX: Int32) -> PopupConfigureSequence {
        PopupConfigureSequence(
            serial: serial,
            placement: PopupPlacement(
                origin: LogicalOffset(x: originX, y: 20),
                size: PositiveLogicalSize(
                    width: PositiveInt32(unchecked: 100),
                    height: PositiveInt32(unchecked: 50)
                )
            )
        )
    }
}
