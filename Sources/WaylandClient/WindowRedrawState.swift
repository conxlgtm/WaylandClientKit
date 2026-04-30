enum RedrawOutcome: Equatable {
    case presented
    case skippedClosed
    case skippedPendingFrame
    case waitingForBuffer
}

struct WindowRedrawState {
    private var contentGeneration: UInt64 = 0
    private var presentedGeneration: UInt64 = 0
    private var frameReady = true
    private var redrawBlockedByBuffer = false
    private var redrawRequestPublished = false

    var isDirty: Bool {
        contentGeneration != presentedGeneration
    }

    var isWaitingForBuffer: Bool {
        redrawBlockedByBuffer
    }

    mutating func markContentDirty() {
        contentGeneration &+= 1
    }

    mutating func markFrameReady() {
        frameReady = true
    }

    mutating func beginDrawAttempt() {
        redrawRequestPublished = false
    }

    mutating func generationForCurrentDraw() -> UInt64 {
        contentGeneration
    }

    mutating func markFramePending() {
        frameReady = false
    }

    mutating func markWaitingForBuffer() {
        redrawBlockedByBuffer = true
    }

    mutating func markPresented(generation: UInt64) {
        presentedGeneration = generation
        redrawBlockedByBuffer = false
        redrawRequestPublished = false
    }

    mutating func resetTransientState() {
        redrawRequestPublished = false
        redrawBlockedByBuffer = false
    }

    mutating func shouldPublishRedrawRequest(bufferUnavailable: Bool) -> Bool {
        guard !redrawRequestPublished else { return false }
        guard isDirty else { return false }
        guard frameReady else { return false }

        if bufferUnavailable {
            redrawBlockedByBuffer = true
            return false
        }

        redrawBlockedByBuffer = false
        redrawRequestPublished = true
        return true
    }
}
