import Testing

@testable import WaylandClient

@Suite
struct PopupModelPresentationTests {
    private let popupID = PopupID(rawValue: 4)
    private let parentWindowID = WindowID(rawValue: 2)

    @Test
    func presentationStateTransitionsFromRequestedToDrawingToIdle() throws {
        var model = try activeModel()

        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))
        let request = try #require(presentationRequest(from: effects))

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
    func presentationStartRequiresIssuedRequest() throws {
        var model = try activeModel()
        let request = PopupPresentationRequest(
            generation: 1,
            placement: configure(serial: 1).placement
        )

        #expect(
            throws: ClientError.window(
                parentWindowID,
                .invalidLifecycleTransition(.presentWithoutRedrawRequest)
            )
        ) {
            _ = try model.reduce(.presentationStarted(request))
        }
    }

    @Test
    func presentationStartRejectsRequestForDifferentPlacement() throws {
        var model = try activeModel()
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))
        let issuedRequest = try #require(presentationRequest(from: effects))
        let staleRequest = PopupPresentationRequest(
            generation: issuedRequest.generation,
            placement: PopupPlacement(
                origin: LogicalOffset(x: 99, y: 20),
                size: issuedRequest.placement.size
            )
        )

        #expect(issuedRequest.summary != staleRequest.summary)
        #expect(
            throws: ClientError.window(
                parentWindowID,
                .invalidLifecycleTransition(
                    .presentationRequestMismatch(
                        .popup(
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
        var model = try activeModel()
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))
        let request = try #require(presentationRequest(from: effects))

        #expect(model.presentation == .requested(request: request))
        #expect(try model.reduce(.transientStateReset).isEmpty)
        #expect(model.presentation == .idle)
    }

    @Test
    func explicitCloseClearsRequestedPresentation() throws {
        var model = try activeModel()
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))
        let request = try #require(presentationRequest(from: effects))

        #expect(model.presentation == .requested(request: request))
        _ = try model.reduce(.explicitClose)
        #expect(model.isDestroyed)
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
