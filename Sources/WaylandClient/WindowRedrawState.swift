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
    case drawBlockedByBuffer
    case presented(generation: UInt64)
    case transientStateReset
}

enum WindowRedrawEffect: Equatable, Sendable {
    case publishRedrawRequested
}

struct WindowRedrawState: Equatable, Sendable {
    private enum CleanPacing: Equatable, Sendable {
        case frameReady
        case waitingForFrame
    }

    private enum RedrawRequest: Equatable, Sendable {
        case none
        case outstanding
    }

    private enum DirtyPacing: Equatable, Sendable {
        case frameReady(RedrawRequest)
        case waitingForFrame
        case waitingForBuffer
    }

    private enum Storage: Equatable, Sendable {
        case clean(generation: UInt64, pacing: CleanPacing)
        case dirty(
            contentGeneration: UInt64,
            presentedGeneration: UInt64,
            pacing: DirtyPacing
        )
    }

    private var storage = Storage.clean(generation: 0, pacing: .frameReady)

    var isDirty: Bool {
        if case .dirty = storage {
            return true
        }

        return false
    }

    var isWaitingForBuffer: Bool {
        if case .dirty(_, _, .waitingForBuffer) = storage {
            return true
        }

        return false
    }

    var hasOutstandingRedrawRequest: Bool {
        if case .dirty(_, _, .frameReady(.outstanding)) = storage {
            return true
        }

        return false
    }

    var generationForCurrentDraw: UInt64 {
        switch storage {
        case .clean(let generation, _):
            generation
        case .dirty(let contentGeneration, _, _):
            contentGeneration
        }
    }

    mutating func reduce(
        _ event: WindowRedrawEvent,
        bufferAvailable: Bool
    ) -> [WindowRedrawEffect] {
        switch event {
        case .contentInvalidated:
            invalidateContent()
            return publishIfNeeded(bufferAvailable: bufferAvailable)
        case .frameBecameReady:
            markFrameReady()
            return publishIfNeeded(bufferAvailable: bufferAvailable)
        case .bufferBecameAvailable:
            markBufferAvailable()
            return publishIfNeeded(bufferAvailable: bufferAvailable)
        case .redrawRequestConsumed:
            markRedrawRequestConsumed()
            return []
        case .drawBlockedByBuffer:
            markDrawBlockedByBuffer()
            return []
        case .presented(let generation):
            markPresented(generation: generation)
            return []
        case .transientStateReset:
            resetTransientState()
            return []
        }
    }
}

extension WindowRedrawState {
    private mutating func invalidateContent() {
        switch storage {
        case .clean(let generation, let pacing):
            storage = .dirty(
                contentGeneration: generation &+ 1,
                presentedGeneration: generation,
                pacing: Self.dirtyPacing(for: pacing)
            )
        case .dirty(let contentGeneration, let presentedGeneration, let pacing):
            storage = .dirty(
                contentGeneration: contentGeneration &+ 1,
                presentedGeneration: presentedGeneration,
                pacing: pacing
            )
        }
    }

    private mutating func markFrameReady() {
        switch storage {
        case .clean(let generation, _):
            storage = .clean(generation: generation, pacing: .frameReady)
        case .dirty(let contentGeneration, let presentedGeneration, .waitingForFrame):
            storage = .dirty(
                contentGeneration: contentGeneration,
                presentedGeneration: presentedGeneration,
                pacing: .frameReady(.none)
            )
        case .dirty(_, _, .waitingForBuffer),
            .dirty(_, _, .frameReady):
            break
        }
    }

    private mutating func markBufferAvailable() {
        guard
            case .dirty(
                let contentGeneration,
                let presentedGeneration,
                .waitingForBuffer
            ) = storage
        else {
            return
        }

        storage = .dirty(
            contentGeneration: contentGeneration,
            presentedGeneration: presentedGeneration,
            pacing: .frameReady(.none)
        )
    }

    private mutating func markRedrawRequestConsumed() {
        guard
            case .dirty(
                let contentGeneration,
                let presentedGeneration,
                .frameReady(.outstanding)
            ) = storage
        else {
            return
        }

        storage = .dirty(
            contentGeneration: contentGeneration,
            presentedGeneration: presentedGeneration,
            pacing: .frameReady(.none)
        )
    }

    private mutating func markDrawBlockedByBuffer() {
        guard case .dirty(let contentGeneration, let presentedGeneration, _) = storage else {
            return
        }

        storage = .dirty(
            contentGeneration: contentGeneration,
            presentedGeneration: presentedGeneration,
            pacing: .waitingForBuffer
        )
    }

    private mutating func markPresented(generation presentedGeneration: UInt64) {
        switch storage {
        case .clean(let contentGeneration, _):
            if presentedGeneration >= contentGeneration {
                storage = .clean(generation: presentedGeneration, pacing: .waitingForFrame)
            } else {
                storage = .dirty(
                    contentGeneration: contentGeneration,
                    presentedGeneration: presentedGeneration,
                    pacing: .waitingForFrame
                )
            }
        case .dirty(let contentGeneration, _, _):
            if presentedGeneration >= contentGeneration {
                storage = .clean(generation: presentedGeneration, pacing: .waitingForFrame)
            } else {
                storage = .dirty(
                    contentGeneration: contentGeneration,
                    presentedGeneration: presentedGeneration,
                    pacing: .waitingForFrame
                )
            }
        }
    }

    private mutating func resetTransientState() {
        switch storage {
        case .clean:
            break
        case .dirty(let contentGeneration, let presentedGeneration, .frameReady(.outstanding)),
            .dirty(let contentGeneration, let presentedGeneration, .waitingForBuffer):
            storage = .dirty(
                contentGeneration: contentGeneration,
                presentedGeneration: presentedGeneration,
                pacing: .frameReady(.none)
            )
        case .dirty(_, _, .frameReady(.none)),
            .dirty(_, _, .waitingForFrame):
            break
        }
    }

    private mutating func publishIfNeeded(bufferAvailable: Bool) -> [WindowRedrawEffect] {
        if case .dirty(
            let contentGeneration,
            let presentedGeneration,
            .waitingForBuffer
        ) = storage, bufferAvailable {
            storage = .dirty(
                contentGeneration: contentGeneration,
                presentedGeneration: presentedGeneration,
                pacing: .frameReady(.outstanding)
            )
            return [.publishRedrawRequested]
        }

        guard
            case .dirty(
                let contentGeneration,
                let presentedGeneration,
                .frameReady(.none)
            ) = storage
        else {
            return []
        }

        guard bufferAvailable else {
            storage = .dirty(
                contentGeneration: contentGeneration,
                presentedGeneration: presentedGeneration,
                pacing: .waitingForBuffer
            )
            return []
        }

        storage = .dirty(
            contentGeneration: contentGeneration,
            presentedGeneration: presentedGeneration,
            pacing: .frameReady(.outstanding)
        )
        return [.publishRedrawRequested]
    }

    private static func dirtyPacing(for pacing: CleanPacing) -> DirtyPacing {
        switch pacing {
        case .frameReady:
            .frameReady(.none)
        case .waitingForFrame:
            .waitingForFrame
        }
    }
}
