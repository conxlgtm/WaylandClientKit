import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct WindowLifecycleTransitionTests {
    private let windowID = WindowID(rawValue: 42)

    @Test
    func destroyedWindowRejectsPresentationStartWithDestroyedError() throws {
        var model = try activePublishedModel()
        let request = PresentationRequest(
            generation: 1,
            configuration: try #require(model.currentConfiguration)
        )

        _ = try model.reduce(.explicitClose)

        #expect(
            throws: ClientError.window(
                windowID,
                .invalidLifecycleTransition(.presentAfterDestroyed)
            )
        ) {
            _ = try model.reduce(.presentationStarted(request))
        }
    }

    @Test
    func destroyedWindowRejectsConfigureCallback() throws {
        var model = try activePublishedModel()

        _ = try model.reduce(.explicitClose)

        #expect(
            throws: ClientError.window(
                windowID,
                .invalidLifecycleTransition(.redrawAfterDestroyed)
            )
        ) {
            _ = try model.reduce(.configureReceived(configure(width: 640, height: 480)))
        }
    }

    @Test
    func staleCallbacksAfterCloseAreNoOpTransitionTable() throws {
        let callbackEvents: [WindowEvent] = [
            .contentInvalidated(bufferAvailability: .available),
            .frameBecameReady(bufferAvailability: .available),
            .bufferBecameAvailable(bufferAvailability: .available),
            .transientStateReset,
        ]

        for callbackEvent in callbackEvents {
            var model = try activePublishedModel()

            _ = try model.reduce(.explicitClose)

            #expect(try model.reduce(callbackEvent).isEmpty)
            #expect(model.isDestroyed)
            #expect(model.presentation == .idle)
            #expect(!model.redraw.isDirty)
        }
    }

    @Test
    func closePublishesClosedExactlyOnceForEveryPublishedClosableLifecycle() throws {
        for model in try publishedClosableModels() {
            var model = model

            let firstEffects = try model.reduce(.explicitClose)
            let secondEffects = try model.reduce(.explicitClose)

            #expect(firstEffects.filter { $0 == .publishClosed(windowID) }.count == 1)
            #expect(!secondEffects.contains(.publishClosed(windowID)))
            #expect(model.publication == .closedPublished(windowID))
        }
    }

    @Test
    func destroyedWindowCannotRemainPublished() throws {
        var model = try activePublishedModel()

        _ = try model.reduce(.explicitClose)

        #expect(model.isDestroyed)
        #expect(model.publication != .published(windowID))
    }

    private func activePublishedModel() throws -> WindowModel {
        var model = WindowModel(id: windowID, fallbackSize: .default)
        _ = try model.reduce(.roleObjectsCreated)
        _ = try model.reduce(.initialCommitSent)
        _ = try model.reduce(.published)
        _ = try model.reduce(.configureReceived(configure(width: 800, height: 600, serial: 1)))
        return model
    }

    private func publishedClosableModels() throws -> [WindowModel] {
        var waiting = WindowModel(id: windowID, fallbackSize: .default)
        _ = try waiting.reduce(.roleObjectsCreated)
        _ = try waiting.reduce(.initialCommitSent)
        _ = try waiting.reduce(.published)

        return [waiting, try activePublishedModel()]
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
