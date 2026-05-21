#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandRaw
    import WaylandTestSupport

    @testable import WaylandClient

    private let activeCapabilities = SurfaceCapabilitySnapshot(
        role: .toplevelWindow,
        outputIDs: [],
        fractionalScale: .integerOnly,
        presentationFeedback: .unavailable,
        dmabuf: .unavailable,
        synchronization: .explicitActive,
        pacing: .fifoAndCommitTiming(fifo: 1, commitTiming: 1)
    )

    private let pacingCapabilities = SurfaceCapabilitySnapshot(
        role: .toplevelWindow,
        outputIDs: [],
        fractionalScale: .integerOnly,
        presentationFeedback: .unavailable,
        dmabuf: .unavailable,
        synchronization: .implicitOnly,
        pacing: .fifoAndCommitTiming(fifo: 1, commitTiming: 1)
    )

    @Suite(.serialized)
    struct SurfaceSubmitConstraintsTests {
        @Test
        func defaultConstraintsValidateForImplicitSurface() throws {
            let capabilities = SurfaceCapabilitySnapshot(
                role: .toplevelWindow,
                outputIDs: [],
                fractionalScale: .integerOnly,
                presentationFeedback: .unavailable,
                dmabuf: .unavailable,
                synchronization: .implicitOnly,
                pacing: .unavailable
            )

            try SurfaceSubmitConstraints.default.validate(
                capabilities: capabilities,
                attachesBuffer: true
            )
        }

        @Test
        func implicitSyncRejectsBufferCommitWhenExplicitSyncIsActive() throws {
            #expect(throws: SurfaceSubmitConstraintError.explicitSyncRequired) {
                try SurfaceSubmitConstraints.default.validate(
                    capabilities: activeCapabilities,
                    attachesBuffer: true
                )
            }

            try SurfaceSubmitConstraints.default.validate(
                capabilities: activeCapabilities,
                attachesBuffer: false
            )
        }

        @Test
        func explicitSyncRequiresActiveSurfaceObject() throws {
            let constraints = SurfaceSubmitConstraints(
                synchronization: .explicit(
                    acquire: nil,
                    release: syncPoint(timeline: 1, point: 1)
                ),
                pacing: .none
            )
            let capabilities = SurfaceCapabilitySnapshot(
                role: .toplevelWindow,
                outputIDs: [],
                fractionalScale: .integerOnly,
                presentationFeedback: .unavailable,
                dmabuf: .unavailable,
                synchronization: .explicitAvailable(version: 1),
                pacing: .unavailable
            )

            #expect(throws: SurfaceSubmitConstraintError.explicitSyncUnavailable) {
                try constraints.validate(capabilities: capabilities, attachesBuffer: true)
            }
        }

        @Test
        func explicitSyncRequiresAcquirePointForBufferCommit() throws {
            let constraints = SurfaceSubmitConstraints(
                synchronization: .explicit(
                    acquire: nil,
                    release: syncPoint(timeline: 1, point: 1)
                ),
                pacing: .none
            )

            #expect(throws: SurfaceSubmitConstraintError.acquirePointRequired) {
                try constraints.validate(capabilities: activeCapabilities, attachesBuffer: true)
            }
        }

        @Test
        func explicitSyncShapeRejectsMissingPointsBeforeCapabilityMutation() throws {
            let constraints = SurfaceSubmitConstraints(
                synchronization: .explicit(
                    acquire: nil,
                    release: syncPoint(timeline: 1, point: 1)
                ),
                pacing: .none
            )

            #expect(throws: SurfaceSubmitConstraintError.acquirePointRequired) {
                try constraints.validateShape(
                    payload: .buffer(
                        RawSurfaceBuffer(
                            pointer: try unsafe #require(
                                OpaquePointer(bitPattern: 0x5C01)
                            )
                        )
                    )
                )
            }
        }

        @Test
        func explicitSyncRequiresReleasePointForBufferCommit() throws {
            let constraints = SurfaceSubmitConstraints(
                synchronization: .explicit(
                    acquire: syncPoint(timeline: 1, point: 1),
                    release: nil
                ),
                pacing: .none
            )

            #expect(throws: SurfaceSubmitConstraintError.releasePointRequired) {
                try constraints.validate(capabilities: activeCapabilities, attachesBuffer: true)
            }
        }

        @Test
        func explicitSyncAcceptsBufferCommitWithAcquireAndReleasePoints() throws {
            let constraints = SurfaceSubmitConstraints(
                synchronization: .explicit(
                    acquire: syncPoint(timeline: 1, point: 1),
                    release: syncPoint(timeline: 1, point: 2)
                ),
                pacing: .none
            )

            try constraints.validate(capabilities: activeCapabilities, attachesBuffer: true)
        }

        @Test
        func explicitSyncRejectsPointsWithoutBufferCommit() throws {
            let acquireOnly = SurfaceSubmitConstraints(
                synchronization: .explicit(
                    acquire: syncPoint(timeline: 1, point: 1),
                    release: nil
                ),
                pacing: .none
            )
            let releaseOnly = SurfaceSubmitConstraints(
                synchronization: .explicit(
                    acquire: nil,
                    release: syncPoint(timeline: 1, point: 1)
                ),
                pacing: .none
            )

            #expect(throws: SurfaceSubmitConstraintError.acquirePointWithoutAttachedBuffer) {
                try acquireOnly.validate(capabilities: activeCapabilities, attachesBuffer: false)
            }
            #expect(throws: SurfaceSubmitConstraintError.releasePointWithoutAttachedBuffer) {
                try releaseOnly.validate(capabilities: activeCapabilities, attachesBuffer: false)
            }
        }

        @Test
        func explicitSyncAllowsMetadataOnlyCommitWithoutPoints() throws {
            let constraints = SurfaceSubmitConstraints(
                synchronization: .explicit(acquire: nil, release: nil),
                pacing: .none
            )

            try constraints.validate(capabilities: activeCapabilities, attachesBuffer: false)
        }

        @Test
        func explicitSyncRejectsConflictingPointsOnSameTimeline() throws {
            let constraints = SurfaceSubmitConstraints(
                synchronization: .explicit(
                    acquire: syncPoint(timeline: 7, point: 10),
                    release: syncPoint(timeline: 7, point: 9)
                ),
                pacing: .none
            )

            #expect(throws: SurfaceSubmitConstraintError.conflictingSyncPoints) {
                try constraints.validate(capabilities: activeCapabilities, attachesBuffer: true)
            }
        }

        @Test
        func explicitSyncAllowsDifferentTimelinePointsWithoutOrdering() throws {
            let constraints = SurfaceSubmitConstraints(
                synchronization: .explicit(
                    acquire: syncPoint(timeline: 7, point: 10),
                    release: syncPoint(timeline: 8, point: 9)
                ),
                pacing: .none
            )

            try constraints.validate(capabilities: activeCapabilities, attachesBuffer: true)
        }

        @Test
        func fifoRequiresFifoCapability() throws {
            let constraints = SurfaceSubmitConstraints(
                synchronization: .implicit,
                pacing: .fifo(.waitBarrier)
            )
            let capabilities = SurfaceCapabilitySnapshot(
                role: .toplevelWindow,
                outputIDs: [],
                fractionalScale: .integerOnly,
                presentationFeedback: .unavailable,
                dmabuf: .unavailable,
                synchronization: .implicitOnly,
                pacing: .commitTiming(version: 1)
            )

            #expect(throws: SurfaceSubmitConstraintError.fifoUnavailable) {
                try constraints.validate(capabilities: capabilities, attachesBuffer: true)
            }
        }

        @Test
        func commitTimingRequiresCommitTimingCapability() throws {
            let target = try SurfaceCommitTargetTime(seconds: 1, nanoseconds: 2)
            let constraints = SurfaceSubmitConstraints(
                synchronization: .implicit,
                pacing: .targetTime(target)
            )
            let capabilities = SurfaceCapabilitySnapshot(
                role: .toplevelWindow,
                outputIDs: [],
                fractionalScale: .integerOnly,
                presentationFeedback: .unavailable,
                dmabuf: .unavailable,
                synchronization: .implicitOnly,
                pacing: .fifo(version: 1)
            )

            #expect(throws: SurfaceSubmitConstraintError.commitTimingUnavailable) {
                try constraints.validate(capabilities: capabilities, attachesBuffer: true)
            }
        }

        @Test
        func commitTargetTimeRejectsInvalidNanoseconds() {
            #expect(throws: SurfaceSubmitConstraintError.invalidCommitTimestamp) {
                _ = try SurfaceCommitTargetTime(seconds: 0, nanoseconds: 1_000_000_000)
            }
        }

        @Test
        func fifoAndCommitTimingValidateWhenBothAreAvailable() throws {
            let target = try SurfaceCommitTargetTime(seconds: 1, nanoseconds: 2)
            let constraints = SurfaceSubmitConstraints(
                synchronization: .implicit,
                pacing: .fifoAndTargetTime(.setBarrier, target)
            )

            try constraints.validate(capabilities: pacingCapabilities, attachesBuffer: true)
        }
    }

    @Suite(.serialized)
    struct SurfaceSubmitConstraintObjectsTests {
        @Test
        func submitConstraintObjectsApplySyncPointsToRawSurface() async throws {
            let syncobjPointer = try unsafe #require(OpaquePointer(bitPattern: 0x5A01))
            let timelinePointer = try unsafe #require(OpaquePointer(bitPattern: 0x5A02))
            let syncobjSurface = RawLinuxDrmSyncobjSurface(pointer: syncobjPointer) { pointer in
                unsafe _ = pointer
            }
            let timeline = RawLinuxDrmSyncobjTimeline(pointer: timelinePointer) { pointer in
                unsafe _ = pointer
            }
            var objects = SurfaceSubmitConstraintObjects()

            objects.installSynchronization(syncobjSurface)
            objects.installTimeline(timeline, identity: SurfaceSyncTimelineIdentity(9))

            try await SyncobjRequestRecordingGate.withExclusiveRecording {
                swl_test_syncobj_request_recording_begin()
                defer { swl_test_syncobj_request_recording_end() }

                try objects.apply(
                    SurfaceSubmitConstraints(
                        synchronization: .explicit(
                            acquire: syncPoint(timeline: 9, point: 0x1122_3344_5566_7788),
                            release: syncPoint(timeline: 9, point: 0x99AA_BBCC_DDEE_FF00)
                        ),
                        pacing: .none
                    )
                )

                let record = unsafe swl_test_syncobj_request_record()
                #expect(unsafe record.call_count == 2)
                #expect(unsafe record.kind == SWL_TEST_SYNCOBJ_SET_RELEASE_POINT)
                #expect(unsafe record.object == UnsafeMutableRawPointer(syncobjPointer))
                #expect(unsafe record.timeline == UnsafeMutableRawPointer(timelinePointer))
                #expect(unsafe record.point_hi == 0x99AA_BBCC)
                #expect(unsafe record.point_lo == 0xDDEE_FF00)
            }
        }

        @Test
        func submitConstraintObjectsApplyFifoAndCommitTimingBeforeCommit() async throws {
            let fifoPointer = try unsafe #require(OpaquePointer(bitPattern: 0x5B01))
            let timerPointer = try unsafe #require(OpaquePointer(bitPattern: 0x5B02))
            let fifo = RawFifo(pointer: fifoPointer) { pointer in
                unsafe _ = pointer
            }
            let timer = RawCommitTimer(pointer: timerPointer) { pointer in
                unsafe _ = pointer
            }
            let targetTime = try SurfaceCommitTargetTime(
                seconds: 0x1122_3344_5566_7788,
                nanoseconds: 999_999_999
            )
            var objects = SurfaceSubmitConstraintObjects()

            objects.installFifo(fifo)
            objects.installCommitTimer(timer)

            try await FifoRequestRecordingGate.withExclusiveRecording {
                swl_test_fifo_request_recording_begin()
                defer { swl_test_fifo_request_recording_end() }

                try objects.apply(
                    SurfaceSubmitConstraints(
                        synchronization: .implicit,
                        pacing: .fifo(.waitBarrier)
                    )
                )

                let record = unsafe swl_test_fifo_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_FIFO_WAIT_BARRIER)
                #expect(unsafe record.object == UnsafeMutableRawPointer(fifoPointer))
            }

            try await CommitTimingRequestRecordingGate.withExclusiveRecording {
                swl_test_commit_timing_request_recording_begin()
                defer { swl_test_commit_timing_request_recording_end() }

                try objects.apply(
                    SurfaceSubmitConstraints(
                        synchronization: .implicit,
                        pacing: .targetTime(targetTime)
                    )
                )

                let record = unsafe swl_test_commit_timing_request_record()
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_COMMIT_TIMING_SET_TIMESTAMP)
                #expect(unsafe record.object == UnsafeMutableRawPointer(timerPointer))
                #expect(unsafe record.tv_sec_hi == 0x1122_3344)
                #expect(unsafe record.tv_sec_lo == 0x5566_7788)
                #expect(unsafe record.tv_nsec == 999_999_999)
            }
        }

        @Test
        func commitTimingPendingStateResetsOnlyAfterMarkedCommitted() async throws {
            let timerPointer = try unsafe #require(OpaquePointer(bitPattern: 0x5D01))
            let timer = RawCommitTimer(pointer: timerPointer) { pointer in
                unsafe _ = pointer
            }
            let firstTarget = try SurfaceCommitTargetTime(seconds: 1, nanoseconds: 2)
            let secondTarget = try SurfaceCommitTargetTime(seconds: 3, nanoseconds: 4)
            var objects = SurfaceSubmitConstraintObjects()

            objects.installCommitTimer(timer)

            try await CommitTimingRequestRecordingGate.withExclusiveRecording {
                swl_test_commit_timing_request_recording_begin()
                defer { swl_test_commit_timing_request_recording_end() }

                try objects.apply(
                    SurfaceSubmitConstraints(
                        synchronization: .implicit,
                        pacing: .targetTime(firstTarget)
                    )
                )
                #expect(throws: SurfaceSubmitConstraintError.commitTimestampAlreadyExists) {
                    try objects.apply(
                        SurfaceSubmitConstraints(
                            synchronization: .implicit,
                            pacing: .targetTime(secondTarget)
                        )
                    )
                }

                objects.markCommitted()
                try objects.apply(
                    SurfaceSubmitConstraints(
                        synchronization: .implicit,
                        pacing: .targetTime(secondTarget)
                    )
                )

                let record = unsafe swl_test_commit_timing_request_record()
                #expect(unsafe record.call_count == 2)
                #expect(unsafe record.tv_sec_lo == 3)
                #expect(unsafe record.tv_nsec == 4)
            }
        }

        @Test
        func fifoBarriersApplyInRequestedCommitCycles() async throws {
            let fifoPointer = try unsafe #require(OpaquePointer(bitPattern: 0x5E01))
            let fifo = RawFifo(pointer: fifoPointer) { pointer in
                unsafe _ = pointer
            }
            var objects = SurfaceSubmitConstraintObjects()

            objects.installFifo(fifo)

            try await FifoRequestRecordingGate.withExclusiveRecording {
                swl_test_fifo_request_recording_begin()
                defer { swl_test_fifo_request_recording_end() }

                try objects.apply(
                    SurfaceSubmitConstraints(
                        synchronization: .implicit,
                        pacing: .fifo(.setBarrier)
                    )
                )
                try objects.apply(
                    SurfaceSubmitConstraints(
                        synchronization: .implicit,
                        pacing: .fifo(.waitBarrier)
                    )
                )

                let record = unsafe swl_test_fifo_request_record()
                #expect(unsafe record.call_count == 2)
                #expect(unsafe record.kind == SWL_TEST_FIFO_WAIT_BARRIER)
                #expect(unsafe record.object == UnsafeMutableRawPointer(fifoPointer))
            }
        }
    }

    private func syncPoint(timeline: UInt64, point: UInt64) -> SurfaceSyncPoint {
        SurfaceSyncPoint(
            timeline: SurfaceSyncTimelineIdentity(timeline),
            point: RawSyncobjTimelinePoint(point)
        )
    }

#endif
