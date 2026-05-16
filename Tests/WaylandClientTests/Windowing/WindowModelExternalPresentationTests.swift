import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct WindowModelExternalPresentationTests {
    private let windowID = WindowID(rawValue: 42)

    @Test
    func externalPresentationAdvancesSoftwareGenerationAfterSoftwarePresentation() throws {
        var (model, request) = try activeModelWithStartedPresentation()
        _ = try model.reduce(
            .presentationSucceeded(
                generation: request.generation,
                bufferAvailability: .available
            )
        )

        _ = try model.reduce(
            .externalPresentationSucceeded(
                generation: request.generation + 1,
                bufferAvailability: .available
            )
        )
        _ = try model.reduce(.frameBecameReady(bufferAvailability: .available))
        #expect(
            try model.reduce(.contentInvalidated(bufferAvailability: .available))
                == [.publishRedrawRequested(windowID)]
        )
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))

        #expect(try presentationRequest(from: effects).generation == request.generation + 2)
    }

    @Test
    func externalPresentationAdvancesInitialSoftwareGeneration() throws {
        var model = try activePublishedModel()

        _ = try model.reduce(
            .externalPresentationSucceeded(
                generation: 1,
                bufferAvailability: .available
            )
        )
        _ = try model.reduce(.frameBecameReady(bufferAvailability: .available))
        #expect(
            try model.reduce(.contentInvalidated(bufferAvailability: .available))
                == [.publishRedrawRequested(windowID)]
        )
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailability: .available))

        #expect(try presentationRequest(from: effects).generation == 2)
    }

    @Test
    func externalPresentationFailsDuringSoftwarePresentation() throws {
        var (model, _) = try activeModelWithStartedPresentation()

        do {
            _ = try model.reduce(
                .externalPresentationSucceeded(
                    generation: 1,
                    bufferAvailability: .available
                )
            )
            Issue.record("Expected external presentation during software presentation to throw.")
        } catch ClientError.window(
            windowID,
            .invalidLifecycleTransition(.nestedPresentation)
        ) {
            // Expected while the software presentation is drawing.
        } catch {
            Issue.record("Expected nested presentation error, got \(error).")
        }
    }
}

extension WindowModelExternalPresentationTests {
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
