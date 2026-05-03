import WaylandRaw

package struct WindowModel: Equatable, Sendable {
    let id: WindowID
    let fallbackSize: PositiveTopLevelSize
    var lifecycle = XDGWindowLifecycle.created(.none)
    var publication = WindowPublicationState.notPublished

    init(id windowID: WindowID, fallbackSize initialSize: PositiveTopLevelSize) {
        id = windowID
        fallbackSize = initialSize
    }

    var isClosed: Bool {
        switch lifecycle {
        case .closing, .destroyed:
            true
        case .created, .roleAssigned, .waitingForInitialConfigure, .active:
            false
        }
    }

    var isDestroyed: Bool {
        lifecycle == .destroyed
    }

    var currentConfiguration: ResolvedWindowConfiguration? {
        activeState?.configure
    }

    var closeRequest: CloseRequestState {
        switch lifecycle {
        case .created(let closeRequest),
            .roleAssigned(let closeRequest),
            .waitingForInitialConfigure(let closeRequest):
            closeRequest
        case .active(let activeState):
            activeState.closeRequest
        case .closing, .destroyed:
            .none
        }
    }

    var redraw: WindowRedrawState {
        activeState?.redraw ?? WindowRedrawState()
    }

    var presentation: WindowPresentationState {
        activeState?.presentation ?? .idle
    }

    mutating func markPublished() {
        guard publication == .notPublished else { return }
        publication = .published(id)
    }

    // swiftlint:disable:next cyclomatic_complexity
    mutating func reduce(
        _ event: WindowEvent
    ) throws -> [WindowEffect] {
        switch event {
        case .roleObjectsCreated:
            return try reduceRoleObjectsCreated()
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
        case .presentationStarted(let generation):
            return try reducePresentationStarted(generation: generation)
        case .presentationBlockedByBuffer:
            return try reducePresentationBlockedByBuffer()
        case .presentationSucceeded(let generation, let bufferAvailable):
            return try reducePresentationSucceeded(
                generation: generation,
                bufferAvailable: bufferAvailable
            )
        case .presentationFailed(let generation, let error):
            return try reducePresentationFailed(generation: generation, error)
        case .compositorCloseRequested(let policy):
            return try reduceCompositorCloseRequested(policy: policy)
        case .explicitClose:
            return try beginClosing(reason: .explicitClose, publishRequest: false)
        case .initialConfigureTimedOut(let milliseconds):
            return try beginClosing(
                reason: .initializationFailed(
                    .initialConfigureTimedOut(milliseconds: milliseconds)
                ),
                publishRequest: false
            )
        case .transientStateReset:
            guard !isClosed else { return [] }
            guard var activeState else { return [] }
            _ = activeState.redraw.reduce(.transientStateReset, bufferAvailable: false)
            activeState.presentation = .idle
            lifecycle = .active(activeState)
            return []
        }
    }
}

extension WindowModel {
    private var activeState: ActiveWindowState? {
        guard case .active(let state) = lifecycle else {
            return nil
        }

        return state
    }

    private mutating func reduceRoleObjectsCreated() throws -> [WindowEffect] {
        guard case .created(let closeRequest) = lifecycle else {
            throw invalidTransition(event: "roleObjectsCreated")
        }

        lifecycle = .roleAssigned(closeRequest)
        return []
    }

    private mutating func reduceInitialCommitSent() throws -> [WindowEffect] {
        guard case .roleAssigned(let closeRequest) = lifecycle else {
            throw invalidTransition(event: "initialCommitSent")
        }

        lifecycle = .waitingForInitialConfigure(closeRequest)
        return []
    }

    private mutating func reduceConfigureReceived(
        _ sequence: XDGConfigureSequence
    ) throws -> [WindowEffect] {
        switch lifecycle {
        case .destroyed:
            throw ClientError.window(id, .invalidLifecycleTransition(.redrawAfterDestroyed))
        case .closing:
            return []
        case .created, .roleAssigned:
            throw ClientError.window(id, .invalidLifecycleTransition(.mapBeforeInitialConfigure))
        case .waitingForInitialConfigure, .active:
            break
        }

        let previousSize = currentConfiguration?.size
        let resolved: ResolvedWindowConfiguration
        do {
            resolved = try ResolvedWindowConfiguration(
                sequence: sequence,
                previousSize: previousSize,
                fallbackSize: fallbackSize
            )
        } catch let error as WindowError {
            throw ClientError.window(id, error)
        }
        var nextActiveState = activeState ?? ActiveWindowState(configure: resolved)
        nextActiveState.configure = resolved
        nextActiveState.closeRequest = closeRequest

        var effects: [WindowEffect] = [.ackConfigure(sequence.serial)]
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
    ) throws -> [WindowEffect] {
        guard !isDestroyed else {
            throw ClientError.window(id, .invalidLifecycleTransition(.redrawAfterDestroyed))
        }

        guard var activeState else {
            if case .closing = lifecycle {
                throw ClientError.window(id, .invalidLifecycleTransition(.presentWhileClosing))
            }

            throw ClientError.window(id, .invalidLifecycleTransition(.mapBeforeInitialConfigure))
        }

        guard activeState.presentation == .idle else {
            throw ClientError.window(id, .invalidLifecycleTransition(.nestedPresentation))
        }

        guard activeState.redraw.hasOutstandingRedrawRequest else {
            return []
        }

        _ = activeState.redraw.reduce(
            .redrawRequestConsumed,
            bufferAvailable: bufferAvailable
        )
        let generation = activeState.redraw.generationForCurrentDraw
        let request = PresentationRequest(
            generation: generation,
            configuration: activeState.configure
        )
        lifecycle = .active(activeState)
        return [.performSoftwarePresent(request)]
    }

    private mutating func reducePresentationStarted(
        generation: UInt64
    ) throws -> [WindowEffect] {
        guard var activeState else {
            if case .closing = lifecycle {
                throw ClientError.window(id, .invalidLifecycleTransition(.presentWhileClosing))
            }

            throw ClientError.window(id, .invalidLifecycleTransition(.mapBeforeInitialConfigure))
        }

        guard activeState.presentation == .idle else {
            throw ClientError.window(id, .invalidLifecycleTransition(.nestedPresentation))
        }

        activeState.presentation = .drawing(generation: generation)
        lifecycle = .active(activeState)
        return []
    }

    private mutating func reducePresentationSucceeded(
        generation: UInt64,
        bufferAvailable: Bool
    ) throws -> [WindowEffect] {
        var activeState = try requireActiveWindowState()
        try requireActivePresentation(generation: generation, in: activeState)
        activeState.presentation = .idle
        let effects = mapRedrawEffects(
            activeState.redraw.reduce(
                .presented(generation: generation),
                bufferAvailable: bufferAvailable
            )
        )
        lifecycle = .active(activeState)
        return effects
    }

    private mutating func reducePresentationFailed(
        generation: UInt64,
        _ error: PresentationError
    ) throws -> [WindowEffect] {
        var activeState = try requireActiveWindowState()
        try requireActivePresentation(generation: generation, in: activeState)
        activeState.presentation = .idle
        lifecycle = .active(activeState)
        throw ClientError.window(id, .presentationFailed(error))
    }

    private mutating func reducePresentationBlockedByBuffer() throws -> [WindowEffect] {
        var activeState = try requireActiveWindowState()
        try requireActivePresentation(in: activeState)
        activeState.presentation = .idle
        let effects = mapRedrawEffects(
            activeState.redraw.reduce(.drawBlockedByBuffer, bufferAvailable: false)
        )
        lifecycle = .active(activeState)
        return effects
    }

    private mutating func reduceCompositorCloseRequested(
        policy: CloseRequestPolicy
    ) throws -> [WindowEffect] {
        guard !isDestroyed else {
            throw ClientError.window(id, .invalidLifecycleTransition(.closeAfterDestroyed))
        }

        switch policy {
        case .requestOnly:
            return reduceRequestOnlyCompositorCloseRequested()
        case .autoClose:
            guard var activeState else {
                return try beginClosing(reason: .compositorRequest, publishRequest: true)
            }

            guard activeState.closeRequest == .none else {
                return []
            }

            activeState.closeRequest = .requested
            lifecycle = .active(activeState)

            return try beginClosing(reason: .compositorRequest, publishRequest: true)
        }
    }

    private mutating func reduceRequestOnlyCompositorCloseRequested() -> [WindowEffect] {
        switch lifecycle {
        case .created(let closeRequest):
            guard closeRequest == .none else { return [] }
            lifecycle = .created(.requested)
        case .roleAssigned(let closeRequest):
            guard closeRequest == .none else { return [] }
            lifecycle = .roleAssigned(.requested)
        case .waitingForInitialConfigure(let closeRequest):
            guard closeRequest == .none else { return [] }
            lifecycle = .waitingForInitialConfigure(.requested)
        case .active(var activeState):
            guard activeState.closeRequest == .none else { return [] }
            activeState.closeRequest = .requested
            lifecycle = .active(activeState)
        case .closing, .destroyed:
            return []
        }

        return [.publishCloseRequested(id)]
    }

    private mutating func beginClosing(
        reason: ClosingReason,
        publishRequest: Bool
    ) throws -> [WindowEffect] {
        switch lifecycle {
        case .destroyed:
            return []
        case .closing:
            return []
        case .created, .roleAssigned, .waitingForInitialConfigure, .active:
            break
        }

        lifecycle = .closing(
            ClosingWindowState(
                reason: reason
            )
        )

        var effects: [WindowEffect] = []
        if publishRequest {
            effects.append(.publishCloseRequested(id))
        }
        effects.append(contentsOf: [
            .cancelFrameCallback,
            .retireSwapchain,
            .destroyRoleObjects,
            .destroySurface,
        ])

        if case .published(let windowID) = publication {
            effects.append(.publishClosed(windowID))
            publication = .closedPublished(windowID)
        }

        lifecycle = .destroyed
        return effects
    }

    private mutating func reduceRedraw(
        _ event: WindowRedrawEvent,
        bufferAvailable: Bool
    ) -> [WindowEffect] {
        guard !isClosed else { return [] }
        guard var activeState else { return [] }

        let effects = mapRedrawEffects(
            activeState.redraw.reduce(event, bufferAvailable: bufferAvailable)
        )
        lifecycle = .active(activeState)
        return effects
    }

    private func mapRedrawEffects(_ effects: [WindowRedrawEffect]) -> [WindowEffect] {
        effects.map { effect in
            switch effect {
            case .publishRedrawRequested:
                .publishRedrawRequested(id)
            }
        }
    }

    @discardableResult
    private func requireActivePresentation(in activeState: ActiveWindowState) throws -> UInt64 {
        switch activeState.presentation {
        case .drawing(let generation):
            return generation
        case .idle:
            throw ClientError.window(
                id,
                .invalidLifecycleTransition(.inactivePresentationCompletion)
            )
        }
    }

    private func requireActivePresentation(
        generation actualGeneration: UInt64,
        in activeState: ActiveWindowState
    ) throws {
        let expectedGeneration = try requireActivePresentation(in: activeState)
        guard expectedGeneration == actualGeneration else {
            throw ClientError.window(
                id,
                .invalidLifecycleTransition(
                    .presentationGenerationMismatch(
                        expected: expectedGeneration,
                        actual: actualGeneration
                    )
                )
            )
        }
    }

    private func requireActiveWindowState() throws -> ActiveWindowState {
        guard let activeState else {
            if case .closing = lifecycle {
                throw ClientError.window(id, .invalidLifecycleTransition(.presentWhileClosing))
            }

            throw ClientError.window(id, .invalidLifecycleTransition(.mapBeforeInitialConfigure))
        }

        return activeState
    }

    private func invalidTransition(event: String) -> ClientError {
        ClientError.window(
            id,
            .invalidLifecycleTransition(
                .invalidTransition(from: lifecycle.description, event: event)
            )
        )
    }
}
