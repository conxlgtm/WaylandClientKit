import WaylandRaw

struct ReportedUnknownWindowProtocolValue: Hashable, Sendable {
    let field: UnknownWindowProtocolValueField
    let rawValue: UInt32
}

package struct WindowModel: Equatable, Sendable {
    let id: WindowID
    let fallbackSize: PositiveLogicalSize
    var decoration = DecorationState.unavailable(reason: nil)
    var lifecycle = XDGWindowLifecycle.created(.none)
    var publication = WindowPublicationState.notPublished
    var reportedUnknownProtocolValues: Set<ReportedUnknownWindowProtocolValue> = []

    init(id windowID: WindowID, fallbackSize initialSize: PositiveLogicalSize) {
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
        case .contentInvalidated(let bufferAvailability):
            return reduceRedraw(.contentInvalidated, bufferAvailability: bufferAvailability)
        case .frameBecameReady(let bufferAvailability):
            return reduceRedraw(.frameBecameReady, bufferAvailability: bufferAvailability)
        case .bufferBecameAvailable(let bufferAvailability):
            return reduceRedraw(.bufferBecameAvailable, bufferAvailability: bufferAvailability)
        case .redrawRequestConsumed(let bufferAvailability):
            return try reduceRedrawRequestConsumed(bufferAvailability: bufferAvailability)
        case .presentationStarted(let request):
            return try reducePresentationStarted(request)
        case .presentationBlockedByBuffer: return try reducePresentationBlockedByBuffer()
        case .presentationSucceeded(let generation, let bufferAvailability):
            return try reducePresentationSucceeded(
                generation: generation,
                bufferAvailability: bufferAvailability
            )
        case .externalPresentationSucceeded(let generation, let bufferAvailability):
            return try reduceExternalPresentationSucceeded(
                generation: generation,
                bufferAvailability: bufferAvailability
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
                _ = activeState.redraw.reduce(
                    .transientStateReset,
                    bufferAvailability: .unavailable
                )
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
        _ event: WindowConfigureEvent
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

        let resolved = event.configuration
        var nextActiveState = activeState ?? ActiveWindowState(configure: resolved)
        nextActiveState.configure = resolved
        nextActiveState.closeRequest = closeRequest
        if let mode = resolved.decorationMode {
            _ = try reduceDecorationConfigured(mode)
        }

        var effects = unknownProtocolValueEffects(for: event.unknownValues)
        effects.append(.ackConfigure(event.serial))
        effects.append(
            contentsOf: mapRedrawEffects(
                nextActiveState.redraw.reduce(.contentInvalidated, bufferAvailability: .available)
            )
        )
        lifecycle = .active(nextActiveState)
        return effects
    }

    private mutating func reduceRedrawRequestConsumed(
        bufferAvailability: RedrawBufferAvailability
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
                bufferAvailability: bufferAvailability
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
        bufferAvailability: RedrawBufferAvailability
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
                    bufferAvailability: bufferAvailability
                ),
                windowID: windowID
            )
        }
    }

    private mutating func reduceExternalPresentationSucceeded(
        generation: UInt64,
        bufferAvailability: RedrawBufferAvailability
    ) throws -> [WindowEffect] {
        let windowID = id
        return try transitionActiveWindowState { activeState in
            guard activeState.presentation == .idle else {
                throw ClientError.window(windowID, .invalidLifecycleTransition(.nestedPresentation))
            }

            return Self.mapRedrawEffects(
                activeState.redraw.reduce(
                    .presented(generation: generation),
                    bufferAvailability: bufferAvailability
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
                activeState.redraw.reduce(.drawBlockedByBuffer, bufferAvailability: .unavailable),
                windowID: windowID
            )
        }
    }

    private mutating func reduceRedraw(
        _ event: WindowRedrawEvent,
        bufferAvailability: RedrawBufferAvailability
    ) -> [WindowEffect] {
        guard !isClosed else { return [] }
        let windowID = id
        return updateActiveWindowStateIfPresent { activeState in
            Self.mapRedrawEffects(
                activeState.redraw.reduce(event, bufferAvailability: bufferAvailability),
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
