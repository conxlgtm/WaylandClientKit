import Testing

@testable import WaylandClient

@Suite
struct SurfaceTransactionStateTests {
    @Test
    func configureMustBeReceivedBeforeAck() {
        var state = SurfaceTransactionState()

        #expect(throws: SurfaceTransactionError.ackWithoutConfigure(serial: 4)) {
            try state.acknowledgeConfigure(serial: 4)
        }
    }

    @Test
    func configureAckRecordsLatestSerial() throws {
        var state = SurfaceTransactionState()

        state.recordConfigureReceived(serial: 7)
        try state.acknowledgeConfigure(serial: 7)

        #expect(
            state.snapshot
                == SurfaceTransactionSnapshot(
                    pendingConfigureSerial: nil,
                    acknowledgedConfigureSerial: 7,
                    pendingFrameCallbackGeneration: nil,
                    lastCommittedFrame: nil
                )
        )
    }

    @Test
    func ackRejectsUnexpectedSerial() {
        var state = SurfaceTransactionState()

        state.recordConfigureReceived(serial: 9)

        #expect(
            throws: SurfaceTransactionError.ackSerialMismatch(expected: 9, actual: 8)
        ) {
            try state.acknowledgeConfigure(serial: 8)
        }
    }

    @Test
    func latestConfigureSerialIsTheOnlyAckableSerial() throws {
        var state = SurfaceTransactionState()

        state.recordConfigureReceived(serial: 41)
        state.recordConfigureReceived(serial: 42)

        #expect(throws: SurfaceTransactionError.ackSerialMismatch(expected: 42, actual: 41)) {
            try state.acknowledgeConfigure(serial: 41)
        }

        try state.acknowledgeConfigure(serial: 42)
        #expect(state.snapshot.acknowledgedConfigureSerial == 42)
    }

    @Test
    func contentCommitRequiresConfigureAckAndFrameCallback() throws {
        var state = SurfaceTransactionState()
        let framePlan = try plan()

        #expect(throws: SurfaceTransactionError.commitBeforeConfigureAck(generation: 1)) {
            try state.recordCommittedFrame(generation: 1, plan: framePlan)
        }

        state.recordConfigureReceived(serial: 3)
        try state.acknowledgeConfigure(serial: 3)

        #expect(throws: SurfaceTransactionError.frameCallbackMissing(generation: 1)) {
            try state.recordCommittedFrame(generation: 1, plan: framePlan)
        }
    }

    @Test
    func commitCandidateWithoutConfigureAckDoesNotMutateRuntime() throws {
        let framePlan = try plan()
        var runtime = SurfaceRuntime<Void>(role: .toplevelWindow)

        #expect(throws: SurfaceTransactionError.commitBeforeConfigureAck(generation: 1)) {
            try runtime.validateCommittedFrameCandidate(generation: 1)
        }

        #expect(
            runtime.transactionSnapshot
                == SurfaceTransactionSnapshot(
                    pendingConfigureSerial: nil,
                    acknowledgedConfigureSerial: nil,
                    pendingFrameCallbackGeneration: nil,
                    lastCommittedFrame: nil
                )
        )
        #expect(throws: SurfaceTransactionError.commitBeforeConfigureAck(generation: 1)) {
            try runtime.prepareCommittedFrame(generation: 1, plan: framePlan)
        }
    }

    @Test
    func committedFrameRecordsConfigureSerialAndPlan() throws {
        var state = SurfaceTransactionState()
        let framePlan = try plan()

        state.recordConfigureReceived(serial: 11)
        try state.acknowledgeConfigure(serial: 11)
        try state.requestFrameCallback(generation: 1)
        try state.recordCommittedFrame(generation: 1, plan: framePlan)

        #expect(
            state.snapshot.lastCommittedFrame
                == SurfaceCommittedFrame(
                    generation: 1,
                    configureSerial: 11,
                    plan: framePlan
                )
        )
        #expect(state.snapshot.pendingFrameCallbackGeneration == 1)

        let completedGeneration = try state.completeFrameCallback()

        #expect(completedGeneration == 1)
        #expect(state.snapshot.pendingFrameCallbackGeneration == nil)
    }

    @Test
    func frameCallbackStateRejectsNestedAndMismatchedGenerations() throws {
        var state = SurfaceTransactionState()
        let framePlan = try plan()

        state.recordConfigureReceived(serial: 11)
        try state.acknowledgeConfigure(serial: 11)
        try state.requestFrameCallback(generation: 1)

        #expect(throws: SurfaceTransactionError.frameCallbackAlreadyPending(generation: 1)) {
            try state.requestFrameCallback(generation: 2)
        }
        #expect(
            throws: SurfaceTransactionError.frameCallbackGenerationMismatch(
                expected: 1,
                actual: 2
            )
        ) {
            try state.recordCommittedFrame(generation: 2, plan: framePlan)
        }
        #expect(state.snapshot.lastCommittedFrame == nil)
        #expect(state.snapshot.pendingFrameCallbackGeneration == 1)
    }

    @Test
    func committedFrameGenerationMustAdvance() throws {
        var state = SurfaceTransactionState()
        let framePlan = try plan()

        state.recordConfigureReceived(serial: 11)
        try state.acknowledgeConfigure(serial: 11)
        try state.requestFrameCallback(generation: 2)
        try state.recordCommittedFrame(generation: 2, plan: framePlan)
        _ = try state.completeFrameCallback()
        try state.requestFrameCallback(generation: 2)

        #expect(
            throws: SurfaceTransactionError.commitGenerationDidNotAdvance(
                previous: 2,
                actual: 2
            )
        ) {
            try state.recordCommittedFrame(generation: 2, plan: framePlan)
        }
    }

    @Test
    func nextCommitGenerationComesFromLastCommittedFrame() throws {
        var state = SurfaceTransactionState()
        let framePlan = try plan()

        #expect(state.nextCommitGeneration == 1)

        state.recordConfigureReceived(serial: 11)
        try state.acknowledgeConfigure(serial: 11)
        try state.requestFrameCallback(generation: state.nextCommitGeneration)
        try state.recordCommittedFrame(generation: 1, plan: framePlan)

        #expect(state.nextCommitGeneration == 2)
    }

    @Test
    func transientResetDropsPendingConfigureAndFrameCallback() throws {
        var state = SurfaceTransactionState()

        state.recordConfigureReceived(serial: 5)
        try state.requestFrameCallback(generation: 9)
        state.resetTransientState()

        #expect(
            state.snapshot
                == SurfaceTransactionSnapshot(
                    pendingConfigureSerial: nil,
                    acknowledgedConfigureSerial: nil,
                    pendingFrameCallbackGeneration: nil,
                    lastCommittedFrame: nil
                )
        )
    }

    private func plan() throws -> SurfaceCommitPlan {
        let geometry = try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 80, height: 60),
            scale: .one
        )
        return try SurfaceCommitPlan(
            geometry: geometry,
            bufferScale: 1,
            viewportMode: .omitDestination,
            damageMode: .buffer
        )
    }
}
