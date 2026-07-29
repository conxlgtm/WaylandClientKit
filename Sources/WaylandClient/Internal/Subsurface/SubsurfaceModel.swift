enum SubsurfaceLifecycle: Equatable, Sendable {
    case active
    case closed
}

struct SubsurfacePresentationRequest: Equatable, Sendable {
    let generation: UInt64
    let geometry: SurfaceGeometry
    let synchronizationMode: SubsurfaceSynchronizationMode
}

enum SubsurfaceEvent: Equatable, Sendable {
    case contentInvalidated(bufferAvailability: RedrawBufferAvailability)
    case scaleChanged(bufferAvailability: RedrawBufferAvailability)
    case synchronizationModeChanged(
        SubsurfaceSynchronizationMode,
        bufferAvailability: RedrawBufferAvailability
    )
    case frameBecameReady(bufferAvailability: RedrawBufferAvailability)
    case bufferBecameAvailable(bufferAvailability: RedrawBufferAvailability)
    case redrawRequestConsumed(
        geometry: SurfaceGeometry,
        bufferAvailability: RedrawBufferAvailability
    )
    case redrawRequestCanceled(bufferAvailability: RedrawBufferAvailability)
    case presentationStarted(SubsurfacePresentationRequest)
    case presentationBlockedByBuffer
    case softwarePresentationSuperseded(
        generation: UInt64,
        bufferAvailability: RedrawBufferAvailability
    )
    case presentationSucceeded(
        generation: UInt64,
        bufferAvailability: RedrawBufferAvailability
    )
    case presentationFeedbackFailed
    case transientStateReset
    case explicitClose
    case parentWindowClosed
}

enum SubsurfaceEffect: Equatable, Sendable {
    case publishRedrawRequested
    case performSoftwarePresent(SubsurfacePresentationRequest)
    case cancelFrameCallback
    case retireSwapchain
    case destroyRoleObjects
}

enum SubsurfaceModelError: Error, Equatable, Sendable {
    case closed
    case nestedPresentation
    case presentWithoutRedrawRequest
    case presentationRequestMismatch
    case presentationGenerationMismatch(expected: UInt64, actual: UInt64)
}

struct SubsurfaceModel: Equatable, Sendable {
    var lifecycle: SubsurfaceLifecycle
    var redraw: WindowRedrawState
    var presentation: PresentationState<SubsurfacePresentationRequest>
    var synchronizationMode: SubsurfaceSynchronizationMode

    init(synchronizationMode mode: SubsurfaceSynchronizationMode) {
        lifecycle = .active
        presentation = .idle
        synchronizationMode = mode

        var initialRedraw = WindowRedrawState()
        _ = initialRedraw.reduce(.contentInvalidated, bufferAvailability: .unavailable)
        redraw = initialRedraw
    }

    func isCurrentSoftwarePresentation(
        _ request: SubsurfacePresentationRequest,
        geometry: SurfaceGeometry
    ) -> Bool {
        lifecycle == .active
            && presentation == .drawing(request: request)
            && request.geometry == geometry
            && request.synchronizationMode == synchronizationMode
            && request.generation == redraw.generationForCurrentDraw
    }

    // swiftlint:disable:next cyclomatic_complexity
    mutating func reduce(_ event: SubsurfaceEvent) throws -> [SubsurfaceEffect] {
        switch event {
        case .explicitClose, .parentWindowClosed:
            return close()
        case .contentInvalidated(let bufferAvailability),
            .scaleChanged(let bufferAvailability):
            return invalidateContent(bufferAvailability: bufferAvailability)
        case .synchronizationModeChanged(let mode, let bufferAvailability):
            guard lifecycle == .active else { return [] }
            guard mode != synchronizationMode else { return [] }
            synchronizationMode = mode
            return invalidateContent(bufferAvailability: bufferAvailability)
        case .frameBecameReady(let bufferAvailability):
            return reduceRedraw(.frameBecameReady, bufferAvailability: bufferAvailability)
        case .bufferBecameAvailable(let bufferAvailability):
            return reduceRedraw(.bufferBecameAvailable, bufferAvailability: bufferAvailability)
        case .redrawRequestConsumed(let geometry, let bufferAvailability):
            return try consumeRedrawRequest(
                geometry: geometry,
                bufferAvailability: bufferAvailability
            )
        case .redrawRequestCanceled(let bufferAvailability):
            return reduceRedraw(.redrawRequestCanceled, bufferAvailability: bufferAvailability)
        case .presentationStarted(let request):
            return try startPresentation(request)
        case .presentationBlockedByBuffer:
            return try blockPresentationByBuffer()
        case .softwarePresentationSuperseded(let generation, let bufferAvailability):
            return try supersedePresentation(
                generation: generation,
                bufferAvailability: bufferAvailability
            )
        case .presentationSucceeded(let generation, let bufferAvailability):
            return try completePresentation(
                generation: generation,
                bufferAvailability: bufferAvailability
            )
        case .presentationFeedbackFailed:
            return []
        case .transientStateReset:
            guard lifecycle == .active else { return [] }
            presentation = .idle
            _ = redraw.reduce(.transientStateReset, bufferAvailability: .unavailable)
            return []
        }
    }
}

extension SubsurfaceModel {
    private mutating func invalidateContent(
        bufferAvailability: RedrawBufferAvailability
    ) -> [SubsurfaceEffect] {
        guard lifecycle == .active else { return [] }
        let redrawAvailability =
            presentation.isIdle ? bufferAvailability : .unavailable
        return map(
            redraw.reduce(.contentInvalidated, bufferAvailability: redrawAvailability)
        )
    }

    private mutating func reduceRedraw(
        _ event: WindowRedrawEvent,
        bufferAvailability: RedrawBufferAvailability
    ) -> [SubsurfaceEffect] {
        guard lifecycle == .active else { return [] }
        return map(redraw.reduce(event, bufferAvailability: bufferAvailability))
    }

    private mutating func consumeRedrawRequest(
        geometry: SurfaceGeometry,
        bufferAvailability: RedrawBufferAvailability
    ) throws -> [SubsurfaceEffect] {
        guard lifecycle == .active else { return [] }
        guard presentation.isIdle else { throw SubsurfaceModelError.nestedPresentation }
        guard redraw.isDirty else { return [] }

        if redraw.isWaitingForBuffer, bufferAvailability.isAvailable {
            _ = redraw.reduce(.bufferBecameAvailable, bufferAvailability: bufferAvailability)
        }
        guard redraw.hasOutstandingRedrawRequest else { return [] }

        _ = redraw.reduce(.redrawRequestConsumed, bufferAvailability: bufferAvailability)
        let request = SubsurfacePresentationRequest(
            generation: redraw.generationForCurrentDraw,
            geometry: geometry,
            synchronizationMode: synchronizationMode
        )
        presentation = .requested(request: request)
        return [.performSoftwarePresent(request)]
    }

    private mutating func startPresentation(
        _ request: SubsurfacePresentationRequest
    ) throws -> [SubsurfaceEffect] {
        guard lifecycle == .active else { throw SubsurfaceModelError.closed }
        guard let pendingRequest = presentation.requestedRequest else {
            throw presentation.isIdle
                ? SubsurfaceModelError.presentWithoutRedrawRequest
                : SubsurfaceModelError.nestedPresentation
        }
        guard pendingRequest == request else {
            throw SubsurfaceModelError.presentationRequestMismatch
        }

        presentation = .drawing(request: request)
        return []
    }

    private mutating func blockPresentationByBuffer() throws -> [SubsurfaceEffect] {
        guard case .drawing = presentation else {
            throw SubsurfaceModelError.presentWithoutRedrawRequest
        }
        presentation = .idle
        return map(redraw.reduce(.drawBlockedByBuffer, bufferAvailability: .unavailable))
    }

    private mutating func supersedePresentation(
        generation: UInt64,
        bufferAvailability: RedrawBufferAvailability
    ) throws -> [SubsurfaceEffect] {
        try requireDrawingGeneration(generation)
        presentation = .idle
        let effects = redraw.supersedeSoftwarePresentation(
            bufferAvailability: bufferAvailability
        )
        return map(effects)
    }

    private mutating func completePresentation(
        generation: UInt64,
        bufferAvailability: RedrawBufferAvailability
    ) throws -> [SubsurfaceEffect] {
        try requireDrawingGeneration(generation)
        presentation = .idle
        return map(
            redraw.reduce(
                .presented(generation: generation),
                bufferAvailability: bufferAvailability
            )
        )
    }

    private func requireDrawingGeneration(_ generation: UInt64) throws {
        guard case .drawing(let request) = presentation else {
            throw SubsurfaceModelError.presentWithoutRedrawRequest
        }
        guard request.generation == generation else {
            throw SubsurfaceModelError.presentationGenerationMismatch(
                expected: request.generation,
                actual: generation
            )
        }
    }

    private mutating func close() -> [SubsurfaceEffect] {
        guard lifecycle == .active else { return [] }
        lifecycle = .closed
        presentation = .idle
        _ = redraw.reduce(.transientStateReset, bufferAvailability: .unavailable)
        return [.cancelFrameCallback, .retireSwapchain, .destroyRoleObjects]
    }

    private func map(_ effects: [WindowRedrawEffect]) -> [SubsurfaceEffect] {
        effects.map { effect in
            switch effect {
            case .publishRedrawRequested:
                .publishRedrawRequested
            }
        }
    }
}
