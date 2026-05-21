#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandRaw
    import WaylandTestSupport

    @testable import WaylandClient

    @Suite(.serialized)
    struct SurfaceSubmitConstraintPreflightTests {
        @Test
        func submitConstraintApplySendsNoRequestsWhenPacingPreflightFails() async throws {
            let syncobjPointer = try unsafe #require(OpaquePointer(bitPattern: 0x5C01))
            let timelinePointer = try unsafe #require(OpaquePointer(bitPattern: 0x5C02))
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

                #expect(throws: SurfaceSubmitConstraintError.fifoUnavailable) {
                    try objects.apply(
                        SurfaceSubmitConstraints(
                            synchronization: .explicit(
                                acquire: syncPoint(timeline: 9, point: 1),
                                release: syncPoint(timeline: 9, point: 2)
                            ),
                            pacing: .fifo(.waitBarrier)
                        )
                    )
                }

                let record = unsafe swl_test_syncobj_request_record()
                #expect(unsafe record.call_count == 0)
            }
        }

        @Test
        func failedSubmitConstraintApplicationDoesNotDirtyNextCommit() async throws {
            let syncobjPointer = try unsafe #require(OpaquePointer(bitPattern: 0x5C11))
            let timelinePointer = try unsafe #require(OpaquePointer(bitPattern: 0x5C12))
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

                #expect(throws: SurfaceSubmitConstraintError.fifoUnavailable) {
                    try objects.apply(
                        SurfaceSubmitConstraints(
                            synchronization: .explicit(
                                acquire: syncPoint(timeline: 9, point: 1),
                                release: syncPoint(timeline: 9, point: 2)
                            ),
                            pacing: .fifo(.waitBarrier)
                        )
                    )
                }

                try objects.apply(.default)

                let record = unsafe swl_test_syncobj_request_record()
                #expect(unsafe record.call_count == 0)
            }
        }

        @Test
        func syncRequestsAreEmittedOnlyAfterAllSubmitConstraintsResolve() async throws {
            let syncobjPointer = try unsafe #require(OpaquePointer(bitPattern: 0x5C21))
            let timelinePointer = try unsafe #require(OpaquePointer(bitPattern: 0x5C22))
            let fifoPointer = try unsafe #require(OpaquePointer(bitPattern: 0x5C23))
            let timerPointer = try unsafe #require(OpaquePointer(bitPattern: 0x5C24))
            let syncobjSurface = RawLinuxDrmSyncobjSurface(pointer: syncobjPointer) { pointer in
                unsafe _ = pointer
            }
            let timeline = RawLinuxDrmSyncobjTimeline(pointer: timelinePointer) { pointer in
                unsafe _ = pointer
            }
            let fifo = RawFifo(pointer: fifoPointer) { pointer in
                unsafe _ = pointer
            }
            let timer = RawCommitTimer(pointer: timerPointer) { pointer in
                unsafe _ = pointer
            }
            let targetTime = try SurfaceCommitTargetTime(seconds: 5, nanoseconds: 6)
            var objects = SurfaceSubmitConstraintObjects()

            objects.installSynchronization(syncobjSurface)
            objects.installTimeline(timeline, identity: SurfaceSyncTimelineIdentity(9))
            objects.installFifo(fifo)
            objects.installCommitTimer(timer)

            try await SyncobjRequestRecordingGate.withExclusiveRecording {
                try await FifoRequestRecordingGate.withExclusiveRecording {
                    try await CommitTimingRequestRecordingGate.withExclusiveRecording {
                        swl_test_syncobj_request_recording_begin()
                        swl_test_fifo_request_recording_begin()
                        swl_test_commit_timing_request_recording_begin()
                        defer { swl_test_commit_timing_request_recording_end() }
                        defer { swl_test_fifo_request_recording_end() }
                        defer { swl_test_syncobj_request_recording_end() }

                        try objects.apply(
                            SurfaceSubmitConstraints(
                                synchronization: .explicit(
                                    acquire: syncPoint(timeline: 9, point: 1),
                                    release: syncPoint(timeline: 9, point: 2)
                                ),
                                pacing: .fifoAndTargetTime(.waitBarrier, targetTime)
                            )
                        )

                        #expect(unsafe swl_test_syncobj_request_record().call_count == 2)
                        #expect(unsafe swl_test_fifo_request_record().call_count == 1)
                        #expect(
                            unsafe swl_test_commit_timing_request_record().call_count == 1
                        )
                    }
                }
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
