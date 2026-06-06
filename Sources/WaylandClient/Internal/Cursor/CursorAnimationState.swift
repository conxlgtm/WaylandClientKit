import WaylandCursor

package struct AnimatedCursorFrame {
    package let image: CursorImage

    package init(image frameImage: CursorImage) {
        image = frameImage
    }
}

package struct CursorAnimationAdvance {
    package let frame: AnimatedCursorFrame
    package let frameIndex: Int
    package let generation: UInt64
}

package struct CursorAnimationState {
    private var frames: [AnimatedCursorFrame]
    package private(set) var currentFrameIndex: Int
    package private(set) var generation: UInt64

    package init(
        frames animationFrames: [AnimatedCursorFrame],
        generation initialGeneration: UInt64 = 1
    ) throws(CursorAnimationStateError) {
        guard !animationFrames.isEmpty else {
            throw .emptyFrameSet
        }

        frames = animationFrames
        currentFrameIndex = 0
        generation = initialGeneration
    }

    package var currentFrame: AnimatedCursorFrame {
        frames[currentFrameIndex]
    }

    package var isAnimated: Bool {
        frames.count > 1
    }

    package mutating func replaceFrames(
        _ nextFrames: [AnimatedCursorFrame]
    ) throws(CursorAnimationStateError) {
        guard !nextFrames.isEmpty else {
            throw .emptyFrameSet
        }

        frames = nextFrames
        currentFrameIndex = 0
        generation += 1
    }

    package mutating func advance() -> CursorAnimationAdvance {
        currentFrameIndex = (currentFrameIndex + 1) % frames.count
        generation += 1

        return CursorAnimationAdvance(
            frame: currentFrame,
            frameIndex: currentFrameIndex,
            generation: generation
        )
    }

    package func acceptsScheduledTick(generation scheduledGeneration: UInt64) -> Bool {
        isAnimated && scheduledGeneration == generation
    }

    package mutating func invalidate() {
        generation += 1
    }
}

package enum CursorAnimationStateError: Error, Equatable, Sendable {
    case emptyFrameSet
}
