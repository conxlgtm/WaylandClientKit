import WaylandRaw

package struct WindowModel: Equatable, Sendable {
    let id: WindowID
    let fallbackSize: PositiveTopLevelSize
    var decoration = DecorationState.unavailable(reason: nil)
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

    // swiftlint:disable:next cyclomatic_complexity
    mutating func reduce(
        _ event: WindowEvent
    ) throws -> [WindowEffect] {
        switch event {
        case .roleObjectsCreated:
            return try reduceRoleObjectsCreated()
        case .decorationUnavailable(let reason):
            return try reduceDecorationUnavailable(reason)
        case .decorationObjectCreated(let preference):
            return try reduceDecorationObjectCreated(preference)
        case .decorationPreferenceRequested(let preference):
            return try reduceDecorationPreferenceRequested(preference)
        case .initialCommitSent:
            return try reduceInitialCommitSent()
        case .published:
            return try reducePublished()
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
            return updateActiveWindowStateIfPresent { activeState in
                _ = activeState.redraw.reduce(.transientStateReset, bufferAvailable: false)
                activeState.presentation = .idle
                return []
            }
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

    private mutating func transitionActiveWindowState(
        _ update: (inout ActiveWindowState) throws -> [WindowEffect]
    ) throws -> [WindowEffect] {
        var activeState = try requireActiveWindowState()

        do {
            let effects = try update(&activeState)
            lifecycle = .active(activeState)
            return effects
        } catch {
            lifecycle = .active(activeState)
            throw error
        }
    }

    private mutating func updateActiveWindowStateIfPresent(
        _ update: (inout ActiveWindowState) -> [WindowEffect]
    ) -> [WindowEffect] {
        guard var activeState else {
            return []
        }

        let effects = update(&activeState)
        lifecycle = .active(activeState)
        return effects
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

    private mutating func reducePublished() throws -> [WindowEffect] {
        guard publication == .notPublished else {
            return []
        }

        switch lifecycle {
        case .waitingForInitialConfigure, .active:
            publication = .published(id)
            return []
        case .created, .roleAssigned, .closing, .destroyed:
            throw invalidTransition(event: "published")
        }
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
        if let mode = resolved.decorationMode {
            _ = try reduceDecorationConfigured(mode)
        }

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

        let windowID = id
        return try transitionActiveWindowState { activeState in
            guard activeState.presentation == .idle else {
                throw ClientError.window(windowID, .invalidLifecycleTransition(.nestedPresentation))
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
            activeState.presentation = .requested(request: request)
            return [.performSoftwarePresent(request)]
        }
    }

    private mutating func reducePresentationStarted(
        _ request: PresentationRequest
    ) throws -> [WindowEffect] {
        let windowID = id
        return try transitionActiveWindowState { activeState in
            let pendingRequest: PresentationRequest
            switch activeState.presentation {
            case .idle:
                throw ClientError.window(
                    windowID,
                    .invalidLifecycleTransition(.presentWithoutRedrawRequest)
                )
            case .requested(let request):
                pendingRequest = request
            case .drawing:
                throw ClientError.window(windowID, .invalidLifecycleTransition(.nestedPresentation))
            }
            guard pendingRequest == request else {
                throw ClientError.window(
                    windowID,
                    .invalidLifecycleTransition(
                        .presentationRequestMismatch(
                            .window(
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

    private mutating func reducePresentationSucceeded(
        generation: UInt64,
        bufferAvailable: Bool
    ) throws -> [WindowEffect] {
        let windowID = id
        return try transitionActiveWindowState { activeState in
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
                windowID: windowID
            )
        }
    }

    private mutating func reducePresentationFailed(
        generation: UInt64,
        _ error: PresentationError
    ) throws -> [WindowEffect] {
        let windowID = id
        return try transitionActiveWindowState { activeState in
            try Self.requireActivePresentation(
                generation: generation,
                in: activeState,
                windowID: windowID
            )
            activeState.presentation = .idle
            throw ClientError.window(windowID, .presentationFailed(error))
        }
    }

    private mutating func reducePresentationBlockedByBuffer() throws -> [WindowEffect] {
        let windowID = id
        return try transitionActiveWindowState { activeState in
            try Self.requireActivePresentation(in: activeState, windowID: windowID)
            activeState.presentation = .idle
            return Self.mapRedrawEffects(
                activeState.redraw.reduce(.drawBlockedByBuffer, bufferAvailable: false),
                windowID: windowID
            )
        }
    }

    private mutating func reduceRedraw(
        _ event: WindowRedrawEvent,
        bufferAvailable: Bool
    ) -> [WindowEffect] {
        guard !isClosed else { return [] }
        let windowID = id
        return updateActiveWindowStateIfPresent { activeState in
            Self.mapRedrawEffects(
                activeState.redraw.reduce(event, bufferAvailable: bufferAvailable),
                windowID: windowID
            )
        }
    }

    private func mapRedrawEffects(_ effects: [WindowRedrawEffect]) -> [WindowEffect] {
        Self.mapRedrawEffects(effects, windowID: id)
    }

    private static func mapRedrawEffects(
        _ effects: [WindowRedrawEffect],
        windowID: WindowID
    ) -> [WindowEffect] {
        effects.map { effect in
            switch effect {
            case .publishRedrawRequested:
                .publishRedrawRequested(windowID)
            }
        }
    }

    @discardableResult
    private func requireActivePresentation(in activeState: ActiveWindowState) throws -> UInt64 {
        try Self.requireActivePresentation(in: activeState, windowID: id)
    }

    @discardableResult
    private static func requireActivePresentation(
        in activeState: ActiveWindowState,
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

    private func requireActivePresentation(
        generation actualGeneration: UInt64,
        in activeState: ActiveWindowState
    ) throws {
        try Self.requireActivePresentation(
            generation: actualGeneration,
            in: activeState,
            windowID: id
        )
    }

    private static func requireActivePresentation(
        generation actualGeneration: UInt64,
        in activeState: ActiveWindowState,
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

    private func requireActiveWindowState() throws -> ActiveWindowState {
        guard let activeState else {
            switch lifecycle {
            case .closing:
                throw ClientError.window(id, .invalidLifecycleTransition(.presentWhileClosing))
            case .destroyed:
                throw ClientError.window(id, .invalidLifecycleTransition(.presentAfterDestroyed))
            case .created, .roleAssigned, .waitingForInitialConfigure:
                throw ClientError.window(
                    id,
                    .invalidLifecycleTransition(.mapBeforeInitialConfigure)
                )
            case .active:
                preconditionFailure("active lifecycle must carry active state")
            }
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
