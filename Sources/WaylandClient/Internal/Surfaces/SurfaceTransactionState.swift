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

package enum SurfaceCommittedPayload: Equatable, Sendable {
    case buffer
    case metadataOnly
}

package struct SurfaceCommittedFrame: Equatable, Sendable {
    package let generation: UInt64
    package let configureSerial: UInt32
    package let plan: SurfaceCommitPlan

    package let payload: SurfaceCommittedPayload

    package init(
        generation committedGeneration: UInt64,
        configureSerial committedConfigureSerial: UInt32,
        plan committedPlan: SurfaceCommitPlan,
        payload committedPayload: SurfaceCommittedPayload = .buffer
    ) {
        generation = committedGeneration
        configureSerial = committedConfigureSerial
        plan = committedPlan
        payload = committedPayload
    }
}

package struct SurfaceTransactionSnapshot: Equatable, Sendable {
    package let pendingConfigureSerial: UInt32?
    package let acknowledgedConfigureSerial: UInt32?
    package let pendingFrameCallbackGeneration: UInt64?
    package let lastCommittedFrame: SurfaceCommittedFrame?
    package let hasCommittedBufferContent: Bool

    package init(
        pendingConfigureSerial snapshotPendingConfigureSerial: UInt32?,
        acknowledgedConfigureSerial snapshotAcknowledgedConfigureSerial: UInt32?,
        pendingFrameCallbackGeneration snapshotPendingFrameCallbackGeneration: UInt64?,
        lastCommittedFrame snapshotLastCommittedFrame: SurfaceCommittedFrame?,
        hasCommittedBufferContent snapshotHasCommittedBufferContent: Bool = false
    ) {
        pendingConfigureSerial = snapshotPendingConfigureSerial
        acknowledgedConfigureSerial = snapshotAcknowledgedConfigureSerial
        pendingFrameCallbackGeneration = snapshotPendingFrameCallbackGeneration
        lastCommittedFrame = snapshotLastCommittedFrame
        hasCommittedBufferContent = snapshotHasCommittedBufferContent
    }
}

package struct SurfaceTransactionState: Equatable, Sendable {
    private var pendingConfigureSerial: UInt32?
    private var acknowledgedConfigureSerial: UInt32?
    private var pendingFrameCallbackGeneration: UInt64?
    private var lastCommittedFrame: SurfaceCommittedFrame?
    private var hasCommittedBufferContent = false

    package init() {
        // Starts before any role configure or content frame commit.
    }

    package var snapshot: SurfaceTransactionSnapshot {
        SurfaceTransactionSnapshot(
            pendingConfigureSerial: pendingConfigureSerial,
            acknowledgedConfigureSerial: acknowledgedConfigureSerial,
            pendingFrameCallbackGeneration: pendingFrameCallbackGeneration,
            lastCommittedFrame: lastCommittedFrame,
            hasCommittedBufferContent: hasCommittedBufferContent
        )
    }

    package var nextCommitGeneration: UInt64 {
        (lastCommittedFrame?.generation ?? 0) + 1
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

    package mutating func markConfigureIndependentRoleReady() {
        pendingConfigureSerial = nil
        acknowledgedConfigureSerial = 0
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
        plan: SurfaceCommitPlan,
        payload: SurfaceCommittedPayload = .buffer
    ) throws {
        let acknowledgedConfigureSerial = try validateCommittedFrameCandidate(
            generation: generation
        )
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
            plan: plan,
            payload: payload
        )
        if payload == .buffer {
            hasCommittedBufferContent = true
        }
    }

    @discardableResult
    package func validateCommittedFrameCandidate(
        generation: UInt64
    ) throws -> UInt32 {
        guard let acknowledgedConfigureSerial else {
            throw SurfaceTransactionError.commitBeforeConfigureAck(generation: generation)
        }
        if let lastGeneration = lastCommittedFrame?.generation, generation <= lastGeneration {
            throw SurfaceTransactionError.commitGenerationDidNotAdvance(
                previous: lastGeneration,
                actual: generation
            )
        }

        return acknowledgedConfigureSerial
    }

    package mutating func resetTransientState() {
        pendingConfigureSerial = nil
        pendingFrameCallbackGeneration = nil
    }
}
