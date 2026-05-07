package enum PopupEvent: Equatable, Sendable {
    case initialCommitSent
    case configureReceived(PopupConfigureSequence)
    case contentInvalidated(bufferAvailable: Bool)
    case frameBecameReady(bufferAvailable: Bool)
    case bufferBecameAvailable(bufferAvailable: Bool)
    case redrawRequestConsumed(bufferAvailable: Bool)
    case presentationStarted(PopupPresentationRequest)
    case presentationBlockedByBuffer
    case presentationSucceeded(generation: UInt64, bufferAvailable: Bool)
    case presentationFailed(generation: UInt64, PresentationError)
    case explicitClose
    case compositorDismissed
    case transientStateReset
}

package enum PopupEffect: Equatable, Sendable {
    case ackConfigure(UInt32)
    case publishDismissed(PopupLifecycleEvent)
    case publishClosed(PopupLifecycleEvent)
    case publishRedrawRequested(PopupLifecycleEvent)
    case cancelFrameCallback
    case performSoftwarePresent(PopupPresentationRequest)
    case retireSwapchain
    case destroyRoleObjects
}

package struct PopupPresentationRequest: Equatable, Sendable {
    package let generation: UInt64
    package let placement: PopupPlacement

    var summary: PopupPresentationRequestSummary {
        PopupPresentationRequestSummary(generation: generation, placement: placement)
    }
}

package typealias PopupPresentationState = PresentationState<PopupPresentationRequest>

package enum PopupLifecycle: Equatable, Sendable, CustomStringConvertible {
    case created
    case waitingForInitialConfigure
    case active(ActivePopupState)
    case closing
    case destroyed

    package var description: String {
        switch self {
        case .created:
            "created"
        case .waitingForInitialConfigure:
            "waitingForInitialConfigure"
        case .active:
            "active"
        case .closing:
            "closing"
        case .destroyed:
            "destroyed"
        }
    }
}

package struct ActivePopupState: Equatable, Sendable {
    package var placement: PopupPlacement
    var redraw = WindowRedrawState()
    package var presentation = PopupPresentationState.idle
}

package struct PopupModel: Equatable, Sendable {
    package let id: PopupID
    package let parentWindowID: WindowID
    package let fallbackSize: PositiveLogicalSize
    package var lifecycle = PopupLifecycle.created

    package init(
        id popupID: PopupID,
        parentWindowID popupParentWindowID: WindowID,
        fallbackSize popupFallbackSize: PositiveLogicalSize
    ) {
        id = popupID
        parentWindowID = popupParentWindowID
        fallbackSize = popupFallbackSize
    }

    package var isClosed: Bool {
        switch lifecycle {
        case .closing, .destroyed:
            true
        case .created, .waitingForInitialConfigure, .active:
            false
        }
    }

    package var isDestroyed: Bool {
        lifecycle == .destroyed
    }

    package var currentPlacement: PopupPlacement? {
        activeState?.placement
    }

    package var currentLogicalSize: PositiveLogicalSize {
        currentPlacement?.size ?? fallbackSize
    }

    var redraw: WindowRedrawState {
        activeState?.redraw ?? WindowRedrawState()
    }

    package var presentation: PopupPresentationState {
        activeState?.presentation ?? .idle
    }

    // swiftlint:disable:next cyclomatic_complexity
    package mutating func reduce(_ event: PopupEvent) throws -> [PopupEffect] {
        switch event {
        case .initialCommitSent:
            return try reduceInitialCommitSent()
        case .configureReceived(let sequence):
            return try reduceConfigureReceived(sequence)
        case .contentInvalidated(let bufferAvailable):
            return reduceRedraw(.contentInvalidated, bufferAvailable: bufferAvailable)
        case .frameBecameReady(let bufferAvailable):
            return reduceRedraw(.frameBecameReady, bufferAvailable: bufferAvailable)
        case .bufferBecameAvailable(let bufferAvailable):
            return reduceRedraw(.bufferBecameAvailable, bufferAvailable: bufferAvailable)
        case .redrawRequestConsumed(let bufferAvailable):
            return try reduceRedrawRequestConsumed(bufferAvailable: bufferAvailable)
        case .presentationStarted(let request):
            return try reducePresentationStarted(request)
        case .presentationBlockedByBuffer:
            return try reducePresentationBlockedByBuffer()
        case .presentationSucceeded(let generation, let bufferAvailable):
            return try reducePresentationSucceeded(
                generation: generation,
                bufferAvailable: bufferAvailable
            )
        case .presentationFailed(let generation, let error):
            return try reducePresentationFailed(generation: generation, error)
        case .explicitClose:
            return beginClosing(dismissedByCompositor: false)
        case .compositorDismissed:
            return beginClosing(dismissedByCompositor: true)
        case .transientStateReset:
            return resetTransientState()
        }
    }
}

extension PopupModel {
    private var activeState: ActivePopupState? {
        guard case .active(let state) = lifecycle else {
            return nil
        }

        return state
    }

    private var lifecycleEvent: PopupLifecycleEvent {
        PopupLifecycleEvent(popup: id, parentWindowID: parentWindowID)
    }

    private mutating func transitionActivePopupState(
        _ update: (inout ActivePopupState) throws -> [PopupEffect]
    ) throws -> [PopupEffect] {
        var activeState = try requireActivePopupState()

        do {
            let effects = try update(&activeState)
            lifecycle = .active(activeState)
            return effects
        } catch {
            lifecycle = .active(activeState)
            throw error
        }
    }

    private mutating func updateActivePopupStateIfPresent(
        _ update: (inout ActivePopupState) -> [PopupEffect]
    ) -> [PopupEffect] {
        guard var activeState else {
            return []
        }

        let effects = update(&activeState)
        lifecycle = .active(activeState)
        return effects
    }

    private mutating func reduceInitialCommitSent() throws -> [PopupEffect] {
        guard lifecycle == .created else {
            throw invalidTransition(event: "initialCommitSent")
        }

        lifecycle = .waitingForInitialConfigure
        return []
    }

    private mutating func reduceConfigureReceived(
        _ sequence: PopupConfigureSequence
    ) throws -> [PopupEffect] {
        switch lifecycle {
        case .destroyed:
            throw ClientError.window(
                parentWindowID,
                .invalidLifecycleTransition(.redrawAfterDestroyed)
            )
        case .closing:
            return []
        case .created:
            throw ClientError.window(
                parentWindowID,
                .invalidLifecycleTransition(.mapBeforeInitialConfigure)
            )
        case .waitingForInitialConfigure, .active:
            break
        }

        var nextActiveState = activeState ?? ActivePopupState(placement: sequence.placement)
        nextActiveState.placement = sequence.placement

        var effects: [PopupEffect] = [.ackConfigure(sequence.serial)]
        effects.append(
            contentsOf: mapRedrawEffects(
                nextActiveState.redraw.reduce(.contentInvalidated, bufferAvailable: true)
            )
        )
        lifecycle = .active(nextActiveState)
        return effects
    }

    private mutating func reduceRedrawRequestConsumed(
        bufferAvailable: Bool
    ) throws -> [PopupEffect] {
        let windowID = parentWindowID
        guard !isDestroyed else {
            throw ClientError.window(
                windowID,
                .invalidLifecycleTransition(.redrawAfterDestroyed)
            )
        }

        return try transitionActivePopupState { activeState in
            guard activeState.presentation == .idle else {
                throw ClientError.window(
                    windowID,
                    .invalidLifecycleTransition(.nestedPresentation)
                )
            }

            guard activeState.redraw.hasOutstandingRedrawRequest else {
                return []
            }

            _ = activeState.redraw.reduce(
                .redrawRequestConsumed,
                bufferAvailable: bufferAvailable
            )
            let request = PopupPresentationRequest(
                generation: activeState.redraw.generationForCurrentDraw,
                placement: activeState.placement
            )
            activeState.presentation = .requested(request: request)
            return [.performSoftwarePresent(request)]
        }
    }

    private mutating func reducePresentationStarted(
        _ request: PopupPresentationRequest
    ) throws -> [PopupEffect] {
        let windowID = parentWindowID
        return try transitionActivePopupState { activeState in
            let pendingRequest: PopupPresentationRequest
            switch activeState.presentation {
            case .idle:
                throw ClientError.window(
                    windowID,
                    .invalidLifecycleTransition(.presentWithoutRedrawRequest)
                )
            case .requested(let request):
                pendingRequest = request
            case .drawing:
                throw ClientError.window(
                    windowID,
                    .invalidLifecycleTransition(.nestedPresentation)
                )
            }
            guard pendingRequest == request else {
                throw ClientError.window(
                    windowID,
                    .invalidLifecycleTransition(
                        .presentationRequestMismatch(
                            .popup(
                                expected: pendingRequest.summary,
                                actual: request.summary
                            )
                        )
                    )
                )
            }

            activeState.presentation = .drawing(request: request)
            return []
        }
    }

    private mutating func reducePresentationBlockedByBuffer() throws -> [PopupEffect] {
        let windowID = parentWindowID
        let event = lifecycleEvent
        return try transitionActivePopupState { activeState in
            try Self.requireActivePresentation(
                in: activeState,
                windowID: windowID
            )
            activeState.presentation = .idle
            return Self.mapRedrawEffects(
                activeState.redraw.reduce(.drawBlockedByBuffer, bufferAvailable: false),
                event: event
            )
        }
    }

    private mutating func reducePresentationSucceeded(
        generation: UInt64,
        bufferAvailable: Bool
    ) throws -> [PopupEffect] {
        let windowID = parentWindowID
        let event = lifecycleEvent
        return try transitionActivePopupState { activeState in
            try Self.requireActivePresentation(
                generation: generation,
                in: activeState,
                windowID: windowID
            )
            activeState.presentation = .idle
            return Self.mapRedrawEffects(
                activeState.redraw.reduce(
                    .presented(generation: generation),
                    bufferAvailable: bufferAvailable
                ),
                event: event
            )
        }
    }

    private mutating func reducePresentationFailed(
        generation: UInt64,
        _ error: PresentationError
    ) throws -> [PopupEffect] {
        let windowID = parentWindowID
        return try transitionActivePopupState { activeState in
            try Self.requireActivePresentation(
                generation: generation,
                in: activeState,
                windowID: windowID
            )
            activeState.presentation = .idle
            throw ClientError.window(windowID, .presentationFailed(error))
        }
    }

    private mutating func reduceRedraw(
        _ event: WindowRedrawEvent,
        bufferAvailable: Bool
    ) -> [PopupEffect] {
        guard !isClosed else { return [] }
        let lifecycleEvent = lifecycleEvent
        return updateActivePopupStateIfPresent { activeState in
            Self.mapRedrawEffects(
                activeState.redraw.reduce(event, bufferAvailable: bufferAvailable),
                event: lifecycleEvent
            )
        }
    }

    private mutating func beginClosing(
        dismissedByCompositor: Bool
    ) -> [PopupEffect] {
        switch lifecycle {
        case .destroyed, .closing:
            return []
        case .created, .waitingForInitialConfigure, .active:
            break
        }

        lifecycle = .closing
        var effects: [PopupEffect] = [
            .cancelFrameCallback,
            .retireSwapchain,
            .destroyRoleObjects,
        ]
        if dismissedByCompositor {
            effects.append(.publishDismissed(lifecycleEvent))
        }
        effects.append(.publishClosed(lifecycleEvent))
        lifecycle = .destroyed
        return effects
    }

    private mutating func resetTransientState() -> [PopupEffect] {
        guard !isClosed else { return [] }
        return updateActivePopupStateIfPresent { activeState in
            _ = activeState.redraw.reduce(.transientStateReset, bufferAvailable: false)
            activeState.presentation = .idle
            return []
        }
    }

    private func mapRedrawEffects(_ effects: [WindowRedrawEffect]) -> [PopupEffect] {
        Self.mapRedrawEffects(effects, event: lifecycleEvent)
    }

    private static func mapRedrawEffects(
        _ effects: [WindowRedrawEffect],
        event: PopupLifecycleEvent
    ) -> [PopupEffect] {
        effects.map { effect in
            switch effect {
            case .publishRedrawRequested:
                .publishRedrawRequested(event)
            }
        }
    }

    @discardableResult
    private static func requireActivePresentation(
        in activeState: ActivePopupState,
        windowID: WindowID
    ) throws -> UInt64 {
        switch activeState.presentation {
        case .drawing(let request):
            return request.generation
        case .idle, .requested:
            throw ClientError.window(
                windowID,
                .invalidLifecycleTransition(.inactivePresentationCompletion)
            )
        }
    }

    private static func requireActivePresentation(
        generation actualGeneration: UInt64,
        in activeState: ActivePopupState,
        windowID: WindowID
    ) throws {
        let expectedGeneration = try requireActivePresentation(
            in: activeState,
            windowID: windowID
        )
        guard expectedGeneration == actualGeneration else {
            throw ClientError.window(
                windowID,
                .invalidLifecycleTransition(
                    .presentationGenerationMismatch(
                        expected: expectedGeneration,
                        actual: actualGeneration
                    )
                )
            )
        }
    }

    private func requireActivePopupState() throws -> ActivePopupState {
        guard let activeState else {
            switch lifecycle {
            case .closing:
                throw ClientError.window(
                    parentWindowID,
                    .invalidLifecycleTransition(.presentWhileClosing)
                )
            case .destroyed:
                throw ClientError.window(
                    parentWindowID,
                    .invalidLifecycleTransition(.presentAfterDestroyed)
                )
            case .created, .waitingForInitialConfigure:
                throw ClientError.window(
                    parentWindowID,
                    .invalidLifecycleTransition(.mapBeforeInitialConfigure)
                )
            case .active:
                preconditionFailure("active popup lifecycle must carry active state")
            }
        }

        return activeState
    }

    private func invalidTransition(event: String) -> ClientError {
        ClientError.window(
            parentWindowID,
            .invalidLifecycleTransition(
                .invalidTransition(from: lifecycle.description, event: event)
            )
        )
    }
}
