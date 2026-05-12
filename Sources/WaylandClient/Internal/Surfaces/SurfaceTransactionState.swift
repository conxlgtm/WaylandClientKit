package enum SurfaceTransactionError: Error, Equatable {
    case ackWithoutConfigure(serial: UInt32)
    case ackSerialMismatch(expected: UInt32, actual: UInt32)
    case frameCallbackAlreadyPending(generation: UInt64)
    case frameCallbackMissing(generation: UInt64)
    case frameCallbackGenerationMismatch(expected: UInt64, actual: UInt64)
    case frameDoneWithoutPendingCallback
    case commitBeforeConfigureAck(generation: UInt64)
    case commitGenerationDidNotAdvance(previous: UInt64, actual: UInt64)
}

package struct SurfaceCommittedFrame: Equatable, Sendable {
    package let generation: UInt64
    package let configureSerial: UInt32
    package let plan: SurfaceCommitPlan
}

package struct SurfaceTransactionSnapshot: Equatable, Sendable {
    package let pendingConfigureSerial: UInt32?
    package let acknowledgedConfigureSerial: UInt32?
    package let pendingFrameCallbackGeneration: UInt64?
    package let lastCommittedFrame: SurfaceCommittedFrame?
}

package struct SurfaceTransactionState: Equatable, Sendable {
    private var pendingConfigureSerial: UInt32?
    private var acknowledgedConfigureSerial: UInt32?
    private var pendingFrameCallbackGeneration: UInt64?
    private var lastCommittedFrame: SurfaceCommittedFrame?

    package init() {
        // Starts before any role configure or content frame commit.
    }

    package var snapshot: SurfaceTransactionSnapshot {
        SurfaceTransactionSnapshot(
            pendingConfigureSerial: pendingConfigureSerial,
            acknowledgedConfigureSerial: acknowledgedConfigureSerial,
            pendingFrameCallbackGeneration: pendingFrameCallbackGeneration,
            lastCommittedFrame: lastCommittedFrame
        )
    }

    package mutating func recordConfigureReceived(serial: UInt32) {
        pendingConfigureSerial = serial
    }

    package mutating func acknowledgeConfigure(serial: UInt32) throws {
        guard let pendingConfigureSerial else {
            throw SurfaceTransactionError.ackWithoutConfigure(serial: serial)
        }
        guard pendingConfigureSerial == serial else {
            throw SurfaceTransactionError.ackSerialMismatch(
                expected: pendingConfigureSerial,
                actual: serial
            )
        }

        self.pendingConfigureSerial = nil
        acknowledgedConfigureSerial = serial
    }

    package mutating func requestFrameCallback(generation: UInt64) throws {
        guard let pendingGeneration = pendingFrameCallbackGeneration else {
            pendingFrameCallbackGeneration = generation
            return
        }

        throw SurfaceTransactionError.frameCallbackAlreadyPending(
            generation: pendingGeneration
        )
    }

    package mutating func cancelFrameCallback() {
        pendingFrameCallbackGeneration = nil
    }

    @discardableResult
    package mutating func completeFrameCallback() throws -> UInt64 {
        guard let pendingGeneration = pendingFrameCallbackGeneration else {
            throw SurfaceTransactionError.frameDoneWithoutPendingCallback
        }

        pendingFrameCallbackGeneration = nil
        return pendingGeneration
    }

    package mutating func recordCommittedFrame(
        generation: UInt64,
        plan: SurfaceCommitPlan
    ) throws {
        guard let acknowledgedConfigureSerial else {
            throw SurfaceTransactionError.commitBeforeConfigureAck(generation: generation)
        }
        guard let pendingGeneration = pendingFrameCallbackGeneration else {
            throw SurfaceTransactionError.frameCallbackMissing(generation: generation)
        }
        guard pendingGeneration == generation else {
            throw SurfaceTransactionError.frameCallbackGenerationMismatch(
                expected: pendingGeneration,
                actual: generation
            )
        }
        if let lastGeneration = lastCommittedFrame?.generation, generation <= lastGeneration {
            throw SurfaceTransactionError.commitGenerationDidNotAdvance(
                previous: lastGeneration,
                actual: generation
            )
        }

        lastCommittedFrame = SurfaceCommittedFrame(
            generation: generation,
            configureSerial: acknowledgedConfigureSerial,
            plan: plan
        )
    }

    package mutating func resetTransientState() {
        pendingConfigureSerial = nil
        pendingFrameCallbackGeneration = nil
    }
}
