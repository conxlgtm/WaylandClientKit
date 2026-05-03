import Testing
import WaylandRaw

@testable import WaylandClient

@Suite
struct WindowDecorationModelTests {
    private let windowID = WindowID(rawValue: 42)

    @Test
    func decorationConfigureUpdatesEffectiveModeWithSurfaceConfigure() throws {
        var model = try configuredModelReadyForConfigure()
        _ = try model.reduce(.decorationObjectCreated(.preferServerSide))
        _ = try model.reduce(.decorationPreferenceRequested(.preferServerSide))

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
        var model = try configuredModelReadyForConfigure()
        _ = try model.reduce(.decorationObjectCreated(.preferServerSide))
        _ = try model.reduce(.decorationPreferenceRequested(.preferServerSide))

        _ = try model.reduce(
            .configureReceived(
                configure(width: 800, height: 600, decorationMode: .clientSide)
            )
        )

        #expect(model.decorationMode == .clientSide)
        #expect(model.decoration == .configured(.clientSide))
    }

    @Test
    func decorationUnavailableStateReportsUnavailableMode() throws {
        var model = WindowModel(id: windowID, fallbackSize: .default)

        _ = try model.reduce(.decorationUnavailable(.managerMissing))

        #expect(model.decorationMode == .unavailable)
        #expect(model.decoration == .unavailable(reason: .managerMissing))
    }

    private func configuredModelReadyForConfigure() throws -> WindowModel {
        var model = WindowModel(id: windowID, fallbackSize: .default)
        _ = try model.reduce(.roleObjectsCreated)
        _ = try model.reduce(.initialCommitSent)
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
}
