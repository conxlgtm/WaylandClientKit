import Testing

@testable import WaylandClient

@Suite
struct PopupEffectInterpreterTests {
    private let popupID = PopupID(rawValue: 4)
    private let parentWindowID = WindowID(rawValue: 2)
    private let lifecycleEvent = PopupLifecycleEvent(
        popup: PopupID(rawValue: 4),
        parentWindowID: WindowID(rawValue: 2)
    )

    @Test
    func configureReceivedAcksConfigureAndPublishesRedraw() throws {
        var model = try waitingModel()
        let recorder = PopupEffectRecorder()

        let effects = try model.reduce(.configureReceived(configure(serial: 9)))
        try interpretPopupEffects(
            effects,
            parentWindowID: parentWindowID,
            handlers: recorder.handlers
        )

        #expect(recorder.events == [.ackConfigure(9), .redrawRequested(lifecycleEvent)])
    }

    @Test
    func explicitCloseDestroysRoleObjectsAndPublishesClosedOnce() throws {
        var model = try activeModelWithStartedPresentation().model
        let recorder = PopupEffectRecorder()

        let effects = try model.reduce(.explicitClose)
        try interpretPopupEffects(
            effects,
            parentWindowID: parentWindowID,
            handlers: recorder.handlers
        )
        let secondEffects = try model.reduce(.explicitClose)
        try interpretPopupEffects(
            secondEffects,
            parentWindowID: parentWindowID,
            handlers: recorder.handlers
        )

        #expect(
            recorder.events == [
                .cancelFrameCallback,
                .retireSwapchain,
                .destroyRoleObjects,
                .closed(lifecycleEvent),
            ]
        )
        #expect(secondEffects.isEmpty)
    }

    @Test
    func compositorDismissalPublishesDismissedBeforeClosed() throws {
        var model = try activeModel()
        let recorder = PopupEffectRecorder()

        try interpretPopupEffects(
            model.reduce(.compositorDismissed),
            parentWindowID: parentWindowID,
            handlers: recorder.handlers
        )

        #expect(
            recorder.events == [
                .cancelFrameCallback,
                .retireSwapchain,
                .destroyRoleObjects,
                .dismissed(lifecycleEvent),
                .closed(lifecycleEvent),
            ]
        )
    }

    @Test
    func performSoftwarePresentEffectRequiresDrawInterpreter() {
        let request = PopupPresentationRequest(
            generation: 1,
            placement: configure(serial: 1).placement
        )
        let recorder = PopupEffectRecorder()

        #expect(
            throws: ClientError.window(
                parentWindowID,
                .invalidLifecycleTransition(
                    .invalidTransition(
                        from: "effect interpreter without draw closure",
                        event: "performSoftwarePresent"
                    )
                )
            )
        ) {
            try interpretPopupEffects(
                [.performSoftwarePresent(request)],
                parentWindowID: parentWindowID,
                handlers: recorder.handlers
            )
        }
        #expect(recorder.events.isEmpty)
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
        -> (model: PopupModel, request: PopupPresentationRequest)
    {
        var model = try activeModel()
        let effects = try model.reduce(.redrawRequestConsumed(bufferAvailable: true))
        let request = try #require(presentationRequest(from: effects))
        _ = try model.reduce(.presentationStarted(request))
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

private enum RecordedPopupEffect: Equatable {
    case ackConfigure(UInt32)
    case dismissed(PopupLifecycleEvent)
    case closed(PopupLifecycleEvent)
    case redrawRequested(PopupLifecycleEvent)
    case cancelFrameCallback
    case retireSwapchain
    case destroyRoleObjects
}

private final class PopupEffectRecorder {
    var events: [RecordedPopupEffect] = []

    var handlers: PopupEffectHandlers {
        PopupEffectHandlers(
            ackConfigure: { [self] serial in
                events.append(.ackConfigure(serial))
            },
            publishDismissed: { [self] event in
                events.append(.dismissed(event))
            },
            publishClosed: { [self] event in
                events.append(.closed(event))
            },
            publishRedrawRequested: { [self] event in
                events.append(.redrawRequested(event))
            },
            cancelFrameCallback: { [self] in
                events.append(.cancelFrameCallback)
            },
            retireSwapchain: { [self] in
                events.append(.retireSwapchain)
            },
            destroyRoleObjects: { [self] in
                events.append(.destroyRoleObjects)
            }
        )
    }
}
