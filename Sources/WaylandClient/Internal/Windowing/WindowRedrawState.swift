enum RedrawOutcome: Equatable {
    case presented
    case skippedClosed
    case skippedPendingFrame
    case waitingForBuffer
}

enum WindowRedrawEvent: Equatable, Sendable {
    case contentInvalidated
    case frameBecameReady
    case bufferBecameAvailable
    case redrawRequestConsumed
    case redrawRequestCanceled
    case drawBlockedByBuffer
    case presented(generation: UInt64)
    case transientStateReset
}

enum WindowRedrawEffect: Equatable, Sendable {
    case publishRedrawRequested
}

package enum RedrawBufferAvailability: Equatable, Sendable {
    case available
    case unavailable

    init(isAvailable: Bool) {
        self = isAvailable ? .available : .unavailable
    }

    var isAvailable: Bool {
        self == .available
    }
}

struct WindowRedrawState: Equatable, Sendable {
    private enum RedrawRequest: Equatable, Sendable {
        case none
        case outstanding
    }

    private enum Pacing: Equatable, Sendable {
        case frameReady(RedrawRequest)
        case waitingForFrame
        case waitingForBuffer
    }

    /// Records whether the current content generation has been presented.
    ///
    /// This cannot be derived from the numeric generations alone. Content
    /// invalidation uses wrapping arithmetic, so a wrapped content generation
    /// can compare below or equal to the last presented generation while still
    /// representing newer content.
    private enum PresentationStatus: Equatable, Sendable {
        case current
        case invalidated
    }

    private var contentGeneration: UInt64 = 0
    private var presentedGeneration: UInt64 = 0
    private var presentationStatus = PresentationStatus.current
    private var pacing = Pacing.frameReady(.none)

    var isDirty: Bool {
        presentationStatus == .invalidated
    }

    var isWaitingForBuffer: Bool {
        pacing == .waitingForBuffer
    }

    var hasOutstandingRedrawRequest: Bool {
        pacing == .frameReady(.outstanding)
    }

    var generationForCurrentDraw: UInt64 {
        contentGeneration
    }

    mutating func reduce(
        _ event: WindowRedrawEvent,
        bufferAvailability: RedrawBufferAvailability
    ) -> [WindowRedrawEffect] {
        let effects: [WindowRedrawEffect]
        switch event {
        case .contentInvalidated:
            invalidateContent()
            effects = publishIfNeeded(bufferAvailability: bufferAvailability)
        case .frameBecameReady:
            markFrameReady()
            effects = publishIfNeeded(bufferAvailability: bufferAvailability)
        case .bufferBecameAvailable:
            markBufferAvailable()
            effects = publishIfNeeded(bufferAvailability: bufferAvailability)
        case .redrawRequestConsumed:
            markRedrawRequestConsumed()
            effects = []
        case .redrawRequestCanceled:
            effects = cancelRedrawRequest(bufferAvailability: bufferAvailability)
        case .drawBlockedByBuffer:
            markDrawBlockedByBuffer()
            effects = []
        case .presented(let generation):
            markPresented(generation: generation)
            effects = []
        case .transientStateReset:
            resetTransientState()
            effects = []
        }

        preconditionInvariantsHold()
        return effects
    }
}

extension WindowRedrawState {
    private mutating func invalidateContent() {
        contentGeneration &+= 1
        presentationStatus = .invalidated
    }

    private mutating func markFrameReady() {
        if case .waitingForFrame = pacing {
            pacing = .frameReady(.none)
        }
    }

    private mutating func markBufferAvailable() {
        if case .waitingForBuffer = pacing {
            pacing = .frameReady(.none)
        }
    }

    private mutating func markRedrawRequestConsumed() {
        if case .frameReady(.outstanding) = pacing {
            pacing = .frameReady(.none)
        }
    }

    private mutating func cancelRedrawRequest(
        bufferAvailability: RedrawBufferAvailability
    ) -> [WindowRedrawEffect] {
        guard case .frameReady(.outstanding) = pacing else {
            return []
        }

        pacing = .frameReady(.none)
        return publishIfNeeded(bufferAvailability: bufferAvailability)
    }

    private mutating func markDrawBlockedByBuffer() {
        guard isDirty else { return }
        pacing = .waitingForBuffer
    }

    private mutating func markPresented(generation newPresentedGeneration: UInt64) {
        presentedGeneration = newPresentedGeneration
        if newPresentedGeneration >= contentGeneration {
            contentGeneration = newPresentedGeneration
            presentationStatus = .current
        } else {
            presentationStatus = .invalidated
        }
        pacing = .waitingForFrame
    }

    private mutating func resetTransientState() {
        switch pacing {
        case .frameReady(.outstanding), .waitingForBuffer:
            pacing = .frameReady(.none)
        case .frameReady(.none), .waitingForFrame:
            return
        }
    }

    private mutating func publishIfNeeded(
        bufferAvailability: RedrawBufferAvailability
    ) -> [WindowRedrawEffect] {
        guard isDirty else { return [] }

        if case .waitingForBuffer = pacing, bufferAvailability.isAvailable {
            pacing = .frameReady(.outstanding)
            return [.publishRedrawRequested]
        }

        guard case .frameReady(.none) = pacing else {
            return []
        }

        guard bufferAvailability.isAvailable else {
            pacing = .waitingForBuffer
            return []
        }

        pacing = .frameReady(.outstanding)
        return [.publishRedrawRequested]
    }

    private func preconditionInvariantsHold() {
        if presentationStatus == .current {
            precondition(contentGeneration == presentedGeneration)
        }

        switch pacing {
        case .frameReady(.outstanding), .waitingForBuffer:
            precondition(isDirty)
        case .frameReady(.none), .waitingForFrame:
            break
        }
    }
}
