import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct WindowDecorationModelTests {
    private let windowID = WindowID(rawValue: 42)

    @Test
    func decorationConfigureUpdatesEffectiveModeWithSurfaceConfigure() throws {
        var model = try modelWithDecorationWaitingForConfigure()

        let effects = try model.reduce(
            .configureReceived(
                configure(width: 800, height: 600, decorationMode: .serverSide)
            )
        )

        #expect(effects == [.ackConfigure(1), .publishRedrawRequested(windowID)])
        #expect(model.decorationMode == .serverSide)
        #expect(model.decoration == .configured(.serverSide))
    }

    @Test
    func compositorCanConfigureDifferentDecorationModeThanRequested() throws {
        var model = try modelWithDecorationWaitingForConfigure()

        _ = try model.reduce(
            .configureReceived(
                configure(width: 800, height: 600, decorationMode: .clientSide)
            )
        )

        #expect(model.decorationMode == .clientSide)
        #expect(model.decoration == .configured(.clientSide))
    }

    @Test
    func configureWithoutDecorationModePreservesPreviousEffectiveMode() throws {
        var model = try modelWithDecorationWaitingForConfigure()
        _ = try model.reduce(
            .configureReceived(
                configure(width: 800, height: 600, serial: 1, decorationMode: .serverSide)
            )
        )

        _ = try model.reduce(
            .configureReceived(configure(width: 1_024, height: 768, serial: 2))
        )

        #expect(model.decorationMode == .serverSide)
        #expect(model.decoration == .configured(.serverSide))
    }

    @Test
    func decorationUnavailableStateReportsUnavailableMode() throws {
        var model = WindowModel(id: windowID, fallbackSize: .default)

        _ = try model.reduce(.decorationUnavailable(.managerMissing))

        #expect(model.decorationMode == .unavailable)
        #expect(model.decoration == .unavailable(reason: .managerMissing))
    }

    @Test
    func decorationPreferenceRequestBeforeObjectCreationIsRejected() throws {
        var model = WindowModel(id: windowID, fallbackSize: .default)

        expectInvalidDecorationTransition(event: "decorationPreferenceRequested") {
            _ = try model.reduce(.decorationPreferenceRequested(.preferServerSide))
        }
    }

    @Test
    func decorationConfigureWithoutDecorationObjectIsRejected() throws {
        var model = try configuredModelReadyForConfigure()

        expectInvalidDecorationTransition(event: "decorationConfigured") {
            _ = try model.reduce(
                .configureReceived(
                    configure(width: 800, height: 600, decorationMode: .serverSide)
                )
            )
        }
        #expect(model.decorationMode == .unavailable)
    }

    @Test
    func decorationEventsAfterDestroyedAreRejected() throws {
        var model = try activePublishedModel()
        _ = try model.reduce(.explicitClose)

        expectInvalidDecorationTransition(event: "decorationObjectCreated") {
            _ = try model.reduce(.decorationObjectCreated(.preferServerSide))
        }
    }

    @Test
    func duplicateDecorationPreferenceRequestIsIdempotent() throws {
        var model = WindowModel(id: windowID, fallbackSize: .default)
        _ = try model.reduce(.decorationObjectCreated(.preferServerSide))
        _ = try model.reduce(.decorationPreferenceRequested(.preferServerSide))

        let effects = try model.reduce(.decorationPreferenceRequested(.preferServerSide))

        #expect(effects.isEmpty)
        #expect(model.decoration == .requested(.preferServerSide))
    }

    @Test
    func decorationObjectCreatedAfterConfiguredIsRejected() throws {
        var model = try modelWithDecorationWaitingForConfigure()
        _ = try model.reduce(
            .configureReceived(
                configure(width: 800, height: 600, decorationMode: .serverSide)
            )
        )

        expectInvalidDecorationTransition(event: "decorationObjectCreated") {
            _ = try model.reduce(.decorationObjectCreated(.preferClientSide))
        }
        #expect(model.decoration == .configured(.serverSide))
    }

    private func configuredModelReadyForConfigure() throws -> WindowModel {
        var model = WindowModel(id: windowID, fallbackSize: .default)
        _ = try model.reduce(.roleObjectsCreated)
        _ = try model.reduce(.initialCommitSent)
        return model
    }

    private func modelWithDecorationWaitingForConfigure() throws -> WindowModel {
        var model = WindowModel(id: windowID, fallbackSize: .default)
        _ = try model.reduce(.decorationObjectCreated(.preferServerSide))
        _ = try model.reduce(.decorationPreferenceRequested(.preferServerSide))
        _ = try model.reduce(.roleObjectsCreated)
        _ = try model.reduce(.initialCommitSent)
        return model
    }

    private func activePublishedModel() throws -> WindowModel {
        var model = try configuredModelReadyForConfigure()
        model.markPublished()
        _ = try model.reduce(.configureReceived(configure(width: 800, height: 600)))
        return model
    }

    private func configure(
        width: Int32,
        height: Int32,
        serial: UInt32 = 1,
        decorationMode: RawDecorationMode? = nil
    ) -> XDGConfigureSequence {
        XDGConfigureSequence(
            serial: serial,
            topLevel: XDGTopLevelConfigureSuggestion(
                size: TopLevelSize(width: width, height: height)
            ),
            decorationMode: decorationMode
        )
    }

    private func expectInvalidDecorationTransition(
        event expectedEvent: String,
        _ body: () throws -> Void
    ) {
        do {
            try body()
            Issue.record("Expected invalid decoration transition")
        } catch ClientError.window(
            let caughtWindowID,
            .invalidLifecycleTransition(.invalidTransition(_, let event))
        ) {
            #expect(caughtWindowID == windowID)
            #expect(event == expectedEvent)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
