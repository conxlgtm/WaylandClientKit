import Testing
import WaylandCursor
import WaylandRaw

@testable import WaylandClient

@Suite
struct CursorAnimationStateTests {
    @Test
    func animationRejectsEmptyFrameSet() {
        #expect(throws: CursorAnimationStateError.emptyFrameSet) {
            _ = try CursorAnimationState(frames: [])
        }
    }

    @Test
    func singleFrameAnimationDoesNotAcceptScheduledTicks() throws {
        let frame = try animatedFrame(delay: 100)
        let state = try CursorAnimationState(frames: [frame], generation: 7)

        #expect(!state.isAnimated)
        #expect(!state.acceptsScheduledTick(generation: 7))
        #expect(state.currentFrame.image === frame.image)
    }

    @Test
    func animationAdvancesFramesAndGeneration() throws {
        let first = try animatedFrame(delay: 100)
        let second = try animatedFrame(delay: 200)
        let third = try animatedFrame(delay: 300)
        var state = try CursorAnimationState(
            frames: [first, second, third],
            generation: 11
        )

        let firstAdvance = state.advance()
        let secondAdvance = state.advance()
        let thirdAdvance = state.advance()

        #expect(firstAdvance.frame.image === second.image)
        #expect(firstAdvance.frameIndex == 1)
        #expect(firstAdvance.generation == 12)
        #expect(secondAdvance.frame.image === third.image)
        #expect(secondAdvance.frameIndex == 2)
        #expect(secondAdvance.generation == 13)
        #expect(thirdAdvance.frame.image === first.image)
        #expect(thirdAdvance.frameIndex == 0)
        #expect(thirdAdvance.generation == 14)
    }

    @Test
    func replacingFramesInvalidatesScheduledTicks() throws {
        let original = try animatedFrame(delay: 100)
        let replacement = try animatedFrame(delay: 50)
        var state = try CursorAnimationState(frames: [original, replacement])
        let scheduledGeneration = state.generation

        try state.replaceFrames([replacement])

        #expect(!state.acceptsScheduledTick(generation: scheduledGeneration))
        #expect(state.currentFrame.image === replacement.image)
        #expect(state.currentFrameIndex == 0)
    }

    @Test
    func invalidateRejectsPreviouslyScheduledTick() throws {
        let first = try animatedFrame(delay: 100)
        let second = try animatedFrame(delay: 200)
        var state = try CursorAnimationState(frames: [first, second])
        let scheduledGeneration = state.generation

        #expect(state.acceptsScheduledTick(generation: scheduledGeneration))

        state.invalidate()

        #expect(!state.acceptsScheduledTick(generation: scheduledGeneration))
        #expect(state.acceptsScheduledTick(generation: state.generation))
    }
}

private func animatedFrame(delay: UInt32) throws -> AnimatedCursorFrame {
    try AnimatedCursorFrame(
        image: CursorImage(
            width: 16,
            height: 24,
            hotspotX: 3,
            hotspotY: 4,
            delay: delay,
            buffer: RawBorrowedBuffer(
                pointer: try unsafe #require(OpaquePointer(bitPattern: Int(delay) + 0xB00))
            )
        )
    )
}
