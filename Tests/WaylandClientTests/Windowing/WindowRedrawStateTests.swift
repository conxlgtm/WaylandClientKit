import Testing

@testable import WaylandClient

@Suite
struct WindowRedrawStateTests {
    @Test
    func contentInvalidationPublishesOnceUntilRedrawIsConsumed() {
        var state = WindowRedrawState()

        #expect(
            state.reduce(.contentInvalidated, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
        #expect(state.isDirty)

        #expect(state.reduce(.contentInvalidated, bufferAvailability: .available).isEmpty)
        #expect(state.reduce(.redrawRequestConsumed, bufferAvailability: .available).isEmpty)
        #expect(
            state.reduce(.contentInvalidated, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
    }

    @Test
    func redrawRequestConsumedDoesNotRepublishImmediately() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)

        #expect(state.reduce(.redrawRequestConsumed, bufferAvailability: .available).isEmpty)
        #expect(state.isDirty)
    }

    @Test
    func canceledRedrawRepublishesLatestDirtyGeneration() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        let leasedGeneration = state.generationForCurrentDraw
        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)

        #expect(state.generationForCurrentDraw == leasedGeneration + 1)
        #expect(
            state.reduce(.redrawRequestCanceled, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
        #expect(state.hasOutstandingRedrawRequest)
    }

    @Test
    func canceledRedrawDoesNotRepublishAfterRequestWasConsumed() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)

        #expect(state.reduce(.redrawRequestCanceled, bufferAvailability: .available).isEmpty)
        #expect(state.isDirty)
        #expect(!state.hasOutstandingRedrawRequest)
    }

    @Test
    func staticContentDoesNotPublishAgainWhenFrameBecomesReady() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)
        let drawnGeneration = state.generationForCurrentDraw

        #expect(
            state.reduce(.presented(generation: drawnGeneration), bufferAvailability: .available)
                .isEmpty
        )
        #expect(!state.isDirty)
        #expect(state.reduce(.frameBecameReady, bufferAvailability: .available).isEmpty)
    }

    @Test
    func dirtyContentWaitsForFrameBeforePublishingAgain() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)
        let drawnGeneration = state.generationForCurrentDraw
        _ = state.reduce(.presented(generation: drawnGeneration), bufferAvailability: .available)

        #expect(state.reduce(.contentInvalidated, bufferAvailability: .available).isEmpty)
        #expect(state.isDirty)
        #expect(
            state.reduce(.frameBecameReady, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
    }

    @Test
    func dirtyContentWaitsForBufferBeforePublishingAgain() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)

        #expect(state.reduce(.drawBlockedByBuffer, bufferAvailability: .unavailable).isEmpty)
        #expect(state.isWaitingForBuffer)
        #expect(
            state.reduce(.bufferBecameAvailable, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
        #expect(!state.isWaitingForBuffer)
    }

    @Test
    func contentInvalidatedWaitingForBufferWithAvailableReplacementPublishes() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)
        _ = state.reduce(.drawBlockedByBuffer, bufferAvailability: .unavailable)

        #expect(state.isWaitingForBuffer)
        #expect(
            state.reduce(.contentInvalidated, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
        #expect(!state.isWaitingForBuffer)
        #expect(state.hasOutstandingRedrawRequest)
    }

    @Test
    func contentInvalidatedWaitingForBufferWithoutReplacementKeepsWaiting() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)
        _ = state.reduce(.drawBlockedByBuffer, bufferAvailability: .unavailable)

        #expect(state.isWaitingForBuffer)
        #expect(state.reduce(.contentInvalidated, bufferAvailability: .unavailable).isEmpty)
        #expect(state.isWaitingForBuffer)
    }

    @Test
    func cleanStateCannotWaitForBuffer() {
        var state = WindowRedrawState()

        #expect(state.reduce(.drawBlockedByBuffer, bufferAvailability: .unavailable).isEmpty)
        #expect(!state.isDirty)
        #expect(!state.isWaitingForBuffer)
    }

    @Test
    func presentingOlderGenerationKeepsNewerContentDirtyUntilFrameReady() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.redrawRequestConsumed, bufferAvailability: .available)
        let drawnGeneration = state.generationForCurrentDraw
        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)

        #expect(
            state.reduce(.presented(generation: drawnGeneration), bufferAvailability: .available)
                .isEmpty
        )
        #expect(state.isDirty)
        #expect(
            state.reduce(.frameBecameReady, bufferAvailability: .available)
                == [.publishRedrawRequested]
        )
    }

    @Test
    func invalidatingMaximumGenerationWrapsAndRemainsDirty() {
        var state = WindowRedrawState()

        _ = state.reduce(.presented(generation: .max), bufferAvailability: .available)
        #expect(state.generationForCurrentDraw == .max)
        #expect(!state.isDirty)

        #expect(state.reduce(.contentInvalidated, bufferAvailability: .unavailable).isEmpty)
        #expect(state.generationForCurrentDraw == 0)
        #expect(state.isDirty)
    }

    @Test
    func futurePresentedGenerationAdvancesCleanGeneration() {
        var state = WindowRedrawState()

        _ = state.reduce(.contentInvalidated, bufferAvailability: .available)
        _ = state.reduce(.presented(generation: 100), bufferAvailability: .available)

        #expect(state.generationForCurrentDraw == 100)
        #expect(!state.isDirty)
        #expect(!state.hasOutstandingRedrawRequest)
        #expect(!state.isWaitingForBuffer)
    }

    @Test
    func deterministicCommandTraceMatchesCharacterizedBehavior() {
        var state = WindowRedrawState()
        var model = RedrawTraceModel()
        var generator = RedrawTraceGenerator(seed: 0xC0FF_EE12_3456_789A)
        var operationCounts = Array(repeating: 0, count: RedrawTraceOperation.allCases.count)
        let commandCount = 20_000

        for step in 0..<commandCount {
            let command = generator.nextCommand(currentGeneration: model.contentGeneration)
            operationCounts[command.operation.rawValue] += 1

            let expectedEffects = model.reduce(
                command.event,
                bufferAvailability: command.bufferAvailability
            )
            let actualEffects = state.reduce(
                command.event,
                bufferAvailability: command.bufferAvailability
            )
            let actual = RedrawTraceObservation(state: state, effects: actualEffects)
            let expected = RedrawTraceObservation(model: model, effects: expectedEffects)

            guard actual == expected else {
                Issue.record("Redraw state diverged at trace step \(step) for \(command.event).")
                return
            }
            guard model.invariantsHold else {
                Issue.record("Redraw invariants failed at trace step \(step) for \(command.event).")
                return
            }
            guard actual.publicationIsValid(bufferAvailability: command.bufferAvailability) else {
                Issue.record("Published redraw violated trace invariants at step \(step).")
                return
            }
        }

        #expect(operationCounts.allSatisfy { $0 > 0 })
    }
}

private struct RedrawTraceObservation: Equatable {
    let effects: [WindowRedrawEffect]
    let isDirty: Bool
    let isWaitingForBuffer: Bool
    let hasOutstandingRedrawRequest: Bool
    let contentGeneration: UInt64

    init(state: WindowRedrawState, effects redrawEffects: [WindowRedrawEffect]) {
        effects = redrawEffects
        isDirty = state.isDirty
        isWaitingForBuffer = state.isWaitingForBuffer
        hasOutstandingRedrawRequest = state.hasOutstandingRedrawRequest
        contentGeneration = state.generationForCurrentDraw
    }

    init(model: RedrawTraceModel, effects redrawEffects: [WindowRedrawEffect]) {
        effects = redrawEffects
        isDirty = model.isDirty
        isWaitingForBuffer = model.isWaitingForBuffer
        hasOutstandingRedrawRequest = model.hasOutstandingRedrawRequest
        contentGeneration = model.contentGeneration
    }

    func publicationIsValid(
        bufferAvailability: RedrawBufferAvailability
    ) -> Bool {
        guard !effects.isEmpty else { return true }
        return effects == [.publishRedrawRequested]
            && isDirty
            && hasOutstandingRedrawRequest
            && bufferAvailability == .available
    }
}

private enum RedrawTraceOperation: Int, CaseIterable {
    case contentInvalidated
    case frameBecameReady
    case bufferBecameAvailable
    case redrawRequestConsumed
    case drawBlockedByBuffer
    case presented
    case transientStateReset
}

private struct RedrawTraceCommand {
    let operation: RedrawTraceOperation
    let event: WindowRedrawEvent
    let bufferAvailability: RedrawBufferAvailability
}

/// A compact model of the redraw behavior that existed before state normalization.
private struct RedrawTraceModel {
    private enum Pacing {
        case frameReady(hasOutstandingRequest: Bool)
        case waitingForFrame
        case waitingForBuffer
    }

    private(set) var contentGeneration: UInt64 = 0
    private var presentedGeneration: UInt64 = 0
    private(set) var isDirty = false
    private var pacing = Pacing.frameReady(hasOutstandingRequest: false)

    var isWaitingForBuffer: Bool {
        if case .waitingForBuffer = pacing {
            return true
        }
        return false
    }

    var hasOutstandingRedrawRequest: Bool {
        if case .frameReady(hasOutstandingRequest: true) = pacing {
            return true
        }
        return false
    }

    var invariantsHold: Bool {
        if !isDirty, contentGeneration != presentedGeneration {
            return false
        }
        if hasOutstandingRedrawRequest || isWaitingForBuffer {
            return isDirty
        }
        return true
    }

    mutating func reduce(
        _ event: WindowRedrawEvent,
        bufferAvailability: RedrawBufferAvailability
    ) -> [WindowRedrawEffect] {
        switch event {
        case .contentInvalidated:
            invalidateContent()
            return publishIfNeeded(bufferAvailability: bufferAvailability)
        case .frameBecameReady:
            markFrameReady()
            return publishIfNeeded(bufferAvailability: bufferAvailability)
        case .bufferBecameAvailable:
            markBufferAvailable()
            return publishIfNeeded(bufferAvailability: bufferAvailability)
        case .redrawRequestConsumed:
            consumeRedrawRequest()
            return []
        case .redrawRequestCanceled:
            return cancelRedrawRequest(bufferAvailability: bufferAvailability)
        case .drawBlockedByBuffer:
            markDrawBlockedByBuffer()
            return []
        case .presented(let generation):
            markPresented(generation)
            return []
        case .transientStateReset:
            resetTransientState()
            return []
        }
    }

    private mutating func invalidateContent() {
        contentGeneration &+= 1
        isDirty = true
    }

    private mutating func markFrameReady() {
        if case .waitingForFrame = pacing {
            pacing = .frameReady(hasOutstandingRequest: false)
        }
    }

    private mutating func markBufferAvailable() {
        if case .waitingForBuffer = pacing {
            pacing = .frameReady(hasOutstandingRequest: false)
        }
    }

    private mutating func consumeRedrawRequest() {
        if case .frameReady(hasOutstandingRequest: true) = pacing {
            pacing = .frameReady(hasOutstandingRequest: false)
        }
    }

    private mutating func cancelRedrawRequest(
        bufferAvailability: RedrawBufferAvailability
    ) -> [WindowRedrawEffect] {
        guard case .frameReady(hasOutstandingRequest: true) = pacing else { return [] }

        pacing = .frameReady(hasOutstandingRequest: false)
        return publishIfNeeded(bufferAvailability: bufferAvailability)
    }

    private mutating func markDrawBlockedByBuffer() {
        if isDirty {
            pacing = .waitingForBuffer
        }
    }

    private mutating func markPresented(_ generation: UInt64) {
        presentedGeneration = generation
        if generation >= contentGeneration {
            contentGeneration = generation
            isDirty = false
        } else {
            isDirty = true
        }
        pacing = .waitingForFrame
    }

    private mutating func resetTransientState() {
        switch pacing {
        case .frameReady(hasOutstandingRequest: true), .waitingForBuffer:
            pacing = .frameReady(hasOutstandingRequest: false)
        case .frameReady(hasOutstandingRequest: false), .waitingForFrame:
            break
        }
    }

    private mutating func publishIfNeeded(
        bufferAvailability: RedrawBufferAvailability
    ) -> [WindowRedrawEffect] {
        guard isDirty else { return [] }

        if case .waitingForBuffer = pacing, bufferAvailability == .available {
            pacing = .frameReady(hasOutstandingRequest: true)
            return [.publishRedrawRequested]
        }

        guard case .frameReady(hasOutstandingRequest: false) = pacing else {
            return []
        }

        guard bufferAvailability == .available else {
            pacing = .waitingForBuffer
            return []
        }

        pacing = .frameReady(hasOutstandingRequest: true)
        return [.publishRedrawRequested]
    }
}

/// Generates the same command sequence for a given seed on every test run.
private struct RedrawTraceGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextCommand(currentGeneration: UInt64) -> RedrawTraceCommand {
        let operation =
            RedrawTraceOperation(
                rawValue: Int(next() % UInt64(RedrawTraceOperation.allCases.count))
            ) ?? .contentInvalidated
        let availability = RedrawBufferAvailability(isAvailable: next() & 1 == 0)
        let event =
            switch operation {
            case .contentInvalidated:
                WindowRedrawEvent.contentInvalidated
            case .frameBecameReady:
                WindowRedrawEvent.frameBecameReady
            case .bufferBecameAvailable:
                WindowRedrawEvent.bufferBecameAvailable
            case .redrawRequestConsumed:
                WindowRedrawEvent.redrawRequestConsumed
            case .drawBlockedByBuffer:
                WindowRedrawEvent.drawBlockedByBuffer
            case .presented:
                WindowRedrawEvent.presented(
                    generation: nextPresentedGeneration(currentGeneration: currentGeneration)
                )
            case .transientStateReset:
                WindowRedrawEvent.transientStateReset
            }

        return RedrawTraceCommand(
            operation: operation,
            event: event,
            bufferAvailability: availability
        )
    }

    private mutating func nextPresentedGeneration(currentGeneration: UInt64) -> UInt64 {
        switch next() % 6 {
        case 0:
            currentGeneration
        case 1:
            currentGeneration &- 1
        case 2:
            currentGeneration &+ 1
        case 3:
            0
        case 4:
            .max
        default:
            next()
        }
    }

    private mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
