#if SWL_ENABLE_TESTING
    // swiftlint:disable file_length closure_body_length

    import CWaylandProtocols
    import Testing
    import WaylandRaw
    import WaylandTestSupport

    @testable import WaylandClient

    private struct RoleToken: Equatable {}

    @Suite(.serialized)
    struct SurfaceRuntimeSubmitTests {  // swiftlint:disable:this type_body_length
        @Test
        func submitCapabilitySnapshotPublishesSynchronizationAndPacingFacts() {
            var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

            runtime.setSynchronizationCapability(.explicitAvailable(version: 1))
            runtime.setPacingCapability(.fifoAndCommitTiming(fifo: 1, commitTiming: 1))

            let snapshot = runtime.capabilitySnapshot()

            #expect(snapshot.synchronization == .explicitAvailable(version: 1))
            #expect(snapshot.pacing == .fifoAndCommitTiming(fifo: 1, commitTiming: 1))
        }

        @Test
        func activatingExplicitSynchronizationUpdatesCapabilitySnapshot() throws {
            var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)

            runtime.setSynchronizationCapability(.explicitAvailable(version: 1))
            runtime.setExplicitSynchronizationActive()

            #expect(runtime.capabilitySnapshot().synchronization == .explicitActive)
        }

        @Test
        func missingSubmitConstraintObjectsRejectNonDefaultConstraints() throws {
            var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
            let syncPoint = SurfaceSyncPoint(
                timeline: SurfaceSyncTimelineIdentity(1),
                point: RawSyncobjTimelinePoint(2)
            )
            let targetTime = try SurfaceCommitTargetTime(seconds: 1, nanoseconds: 2)

            runtime.setExplicitSynchronizationActive()
            runtime.setPacingCapability(.fifoAndCommitTiming(fifo: 1, commitTiming: 1))

            #expect(throws: SurfaceSubmitConstraintError.explicitSyncUnavailable) {
                try runtime.applySubmitConstraints(
                    SurfaceSubmitConstraints(
                        synchronization: .explicit(acquire: nil, release: syncPoint),
                        pacing: .none
                    )
                )
            }
            #expect(throws: SurfaceSubmitConstraintError.fifoUnavailable) {
                try runtime.applySubmitConstraints(
                    SurfaceSubmitConstraints(
                        synchronization: .implicit,
                        pacing: .fifo(.waitBarrier)
                    )
                )
            }
            #expect(throws: SurfaceSubmitConstraintError.commitTimingUnavailable) {
                try runtime.applySubmitConstraints(
                    SurfaceSubmitConstraints(
                        synchronization: .implicit,
                        pacing: .targetTime(targetTime)
                    )
                )
            }
        }

        @Test
        func missingSyncTimelineRejectsExplicitConstraintApplication() throws {
            var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
            let syncSurface = try StubSyncobjSurface()
            let syncPoint = SurfaceSyncPoint(
                timeline: SurfaceSyncTimelineIdentity(77),
                point: RawSyncobjTimelinePoint(2)
            )

            runtime.installExplicitSynchronizationObject(syncSurface.object)

            #expect(
                throws: SurfaceSubmitConstraintError.syncTimelineUnavailable(
                    SurfaceSyncTimelineIdentity(77)
                )
            ) {
                try runtime.applySubmitConstraints(
                    SurfaceSubmitConstraints(
                        synchronization: .explicit(acquire: syncPoint, release: syncPoint),
                        pacing: .none
                    )
                )
            }
        }

        @Test
        func frameCommitterRecordsCommittedFrameAfterSurfaceCommit() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let surface = try testSurface(pointer: 0x5601)
                defer { surface.destroy() }
                var runtime = try configuredRuntime()
                let preparedCommit = try preparedCommit(
                    surface: surface,
                    runtime: &runtime,
                    constraints: .default,
                    payload: .buffer(try testSurfaceBuffer(pointer: 0x5602))
                )

                let committedPlan = try SurfaceFrameCommitter.commit(
                    preparedCommit,
                    runtime: &runtime
                )

                #expect(
                    runtime.transactionSnapshot.lastCommittedFrame
                        == SurfaceCommittedFrame(
                            generation: 1,
                            configureSerial: 7,
                            plan: committedPlan,
                            payload: .buffer
                        )
                )
                #expect(runtime.transactionSnapshot.hasCommittedBufferContent)
                #expect(unsafe swl_test_core_request_record().kind == SWL_TEST_CORE_SURFACE_COMMIT)
            }
        }

        @Test
        func frameCommitterDoesNotRecordFrameWhenSubmitConstraintsFail() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let surface = try testSurface(pointer: 0x5701)
                defer { surface.destroy() }
                var runtime = try configuredRuntime()
                runtime.setExplicitSynchronizationActive()
                let preparedCommit = try preparedCommit(
                    surface: surface,
                    runtime: &runtime,
                    constraints: explicitConstraints(timeline: 77, acquire: 2, release: 3),
                    payload: .buffer(try testSurfaceBuffer(pointer: 0x5702))
                )

                #expect(throws: SurfaceSubmitConstraintError.explicitSyncUnavailable) {
                    try SurfaceFrameCommitter.commit(
                        preparedCommit,
                        runtime: &runtime
                    )
                }
                #expect(runtime.transactionSnapshot.lastCommittedFrame == nil)
                #expect(unsafe swl_test_core_request_record().call_count == 0)
            }
        }

        @Test
        func frameCommitterCanPrepareMetadataOnlyCommitWithoutSyncPoints() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let surface = try testSurface(pointer: 0x5801)
                defer { surface.destroy() }
                var runtime = try configuredRuntime()
                runtime.setExplicitSynchronizationActive()

                let preparedCommit = try SurfaceFrameCommitter.prepare(
                    SurfaceFrameCommitRequest(
                        surface: surface,
                        scaleInstallation: SurfaceScaleInstallation(),
                        generation: 1,
                        geometry: try testSurfaceGeometry(),
                        payload: .metadataOnly,
                        submitConstraints: SurfaceSubmitConstraints(
                            synchronization: .explicit(acquire: nil, release: nil),
                            pacing: .none
                        )
                    ),
                    runtime: &runtime,
                )

                #expect(!preparedCommit.payload.attachesBuffer)
            }
        }

        @Test
        func explicitSyncBufferCommitWithoutAcquireReleaseIsRejectedAtCommitBoundary()
            async throws
        {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let surface = try testSurface(pointer: 0x5901)
                defer { surface.destroy() }
                var runtime = try configuredRuntime()
                runtime.setExplicitSynchronizationActive()

                #expect(throws: SurfaceSubmitConstraintError.acquirePointRequired) {
                    try SurfaceFrameCommitter.prepare(
                        SurfaceFrameCommitRequest(
                            surface: surface,
                            scaleInstallation: SurfaceScaleInstallation(),
                            generation: 1,
                            geometry: try testSurfaceGeometry(),
                            payload: .buffer(try testSurfaceBuffer(pointer: 0x5902)),
                            submitConstraints: SurfaceSubmitConstraints(
                                synchronization: .explicit(acquire: nil, release: nil),
                                pacing: .none
                            )
                        ),
                        runtime: &runtime,
                    )
                }
                #expect(unsafe swl_test_core_request_record().call_count == 0)
            }
        }

        @Test
        func metadataOnlyCommitDoesNotAttachBuffer() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let surface = try testSurface(pointer: 0x5A01)
                defer { surface.destroy() }
                var runtime = try configuredRuntime()
                let preparedCommit = try preparedCommit(
                    surface: surface,
                    runtime: &runtime,
                    constraints: .default,
                    payload: .metadataOnly
                )

                _ = try SurfaceFrameCommitter.commit(preparedCommit, runtime: &runtime)

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(unsafe record.attach_sequence == 0)
                #expect(unsafe record.damage_sequence == 0)
                #expect(runtime.transactionSnapshot.lastCommittedFrame?.payload == .metadataOnly)
                #expect(!runtime.transactionSnapshot.hasCommittedBufferContent)
            }
        }

        @Test
        func firstGenerationCommitForcesFullFrameDamage() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let surface = try testSurface(pointer: 0x5D01)
                defer { surface.destroy() }
                var runtime = try configuredRuntime()
                let damageRect = try LogicalRect(x: 10, y: 5, width: 20, height: 15)
                let damage = try SurfaceDamageRegion([damageRect])
                let geometry = try testSurfaceGeometry()
                let preparedCommit = try SurfaceFrameCommitter.prepare(
                    SurfaceFrameCommitRequest(
                        surface: surface,
                        scaleInstallation: SurfaceScaleInstallation(),
                        generation: 1,
                        geometry: geometry,
                        payload: .buffer(try testSurfaceBuffer(pointer: 0x5D02)),
                        damage: damage
                    ),
                    runtime: &runtime,
                )

                #expect(
                    preparedCommit.plan.damage
                        == .logical([
                            LogicalRect(origin: .zero, size: geometry.logicalSize)
                        ])
                )

                _ = try SurfaceFrameCommitter.commit(preparedCommit, runtime: &runtime)

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(unsafe record.damage_sequence > 0)
                #expect(unsafe record.damage_sequence < record.commit_sequence)
                #expect(unsafe record.x == 0)
                #expect(unsafe record.y == 0)
                #expect(unsafe record.width == 80)
                #expect(unsafe record.height == 60)
            }
        }

        @Test
        func firstGenerationInvalidDamageIsRejectedBeforeFullFrameCoercion() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let surface = try testSurface(pointer: 0x5E01)
                defer { surface.destroy() }
                var runtime = try configuredRuntime()
                let damageRect = try LogicalRect(x: 81, y: 0, width: 1, height: 10)
                let damage = try SurfaceDamageRegion([damageRect])

                #expect(throws: SurfaceRegionError.damageRectangleOutOfBounds(damageRect)) {
                    try SurfaceFrameCommitter.prepare(
                        SurfaceFrameCommitRequest(
                            surface: surface,
                            scaleInstallation: SurfaceScaleInstallation(),
                            generation: 1,
                            geometry: try testSurfaceGeometry(),
                            payload: .buffer(try testSurfaceBuffer(pointer: 0x5E02)),
                            damage: damage
                        ),
                        runtime: &runtime,
                    )
                }
                #expect(runtime.transactionSnapshot.lastCommittedFrame == nil)
                #expect(!runtime.transactionSnapshot.hasCommittedBufferContent)
                #expect(unsafe swl_test_core_request_record().call_count == 0)
            }
        }

        @Test
        func firstBufferCommitAfterMetadataOnlyCommitForcesFullFrameDamage() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let surface = try testSurface(pointer: 0x5F01)
                defer { surface.destroy() }
                var runtime = try configuredRuntime()
                let metadataCommit = try preparedCommit(
                    surface: surface,
                    runtime: &runtime,
                    constraints: .default,
                    payload: .metadataOnly
                )
                _ = try SurfaceFrameCommitter.commit(metadataCommit, runtime: &runtime)
                #expect(!runtime.transactionSnapshot.hasCommittedBufferContent)
                _ = try runtime.completeFrameCallback()
                try runtime.requestFrameCallback(generation: 2)

                swl_test_core_request_recording_begin()

                let damage = try SurfaceDamageRegion([
                    LogicalRect(x: 10, y: 5, width: 20, height: 15)
                ])
                let geometry = try testSurfaceGeometry()
                let preparedCommit = try SurfaceFrameCommitter.prepare(
                    SurfaceFrameCommitRequest(
                        surface: surface,
                        scaleInstallation: SurfaceScaleInstallation(),
                        generation: 2,
                        geometry: geometry,
                        payload: .buffer(try testSurfaceBuffer(pointer: 0x5F02)),
                        damage: damage
                    ),
                    runtime: &runtime,
                )

                #expect(
                    preparedCommit.plan.damage
                        == .logical([
                            LogicalRect(origin: .zero, size: geometry.logicalSize)
                        ])
                )

                _ = try SurfaceFrameCommitter.commit(preparedCommit, runtime: &runtime)

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(unsafe record.x == 0)
                #expect(unsafe record.y == 0)
                #expect(unsafe record.width == 80)
                #expect(unsafe record.height == 60)
                #expect(runtime.transactionSnapshot.hasCommittedBufferContent)
            }
        }

        @Test
        func explicitLogicalDamageIsCommittedWhenBufferDamageIsUnavailable() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let surface = try testSurface(pointer: 0x5C01)
                defer { surface.destroy() }
                var runtime = try configuredRuntime()
                let firstCommit = try preparedCommit(
                    surface: surface,
                    runtime: &runtime,
                    constraints: .default,
                    payload: .buffer(try testSurfaceBuffer(pointer: 0x5C02))
                )
                _ = try SurfaceFrameCommitter.commit(firstCommit, runtime: &runtime)
                _ = try runtime.completeFrameCallback()
                try runtime.requestFrameCallback(generation: 2)

                swl_test_core_request_recording_begin()

                let damage = try SurfaceDamageRegion([
                    LogicalRect(
                        origin: LogicalOffset(x: 10, y: 5),
                        size: PositiveLogicalSize(width: 20, height: 15)
                    )
                ])
                let preparedCommit = try SurfaceFrameCommitter.prepare(
                    SurfaceFrameCommitRequest(
                        surface: surface,
                        scaleInstallation: SurfaceScaleInstallation(),
                        generation: 2,
                        geometry: try SurfaceGeometry(
                            logicalSize: PositiveLogicalSize(width: 80, height: 60),
                            scale: SurfaceScale(numerator: 2, denominator: 1)
                        ),
                        payload: .buffer(try testSurfaceBuffer(pointer: 0x5C03)),
                        damage: damage
                    ),
                    runtime: &runtime,
                )

                _ = try SurfaceFrameCommitter.commit(preparedCommit, runtime: &runtime)

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(unsafe record.damage_sequence > 0)
                #expect(unsafe record.damage_sequence < record.commit_sequence)
                #expect(unsafe record.x == 10)
                #expect(unsafe record.y == 5)
                #expect(unsafe record.width == 20)
                #expect(unsafe record.height == 15)
            }
        }

        @Test
        func preparedMetadataOnlyCommitCannotBeCommittedWithBuffer() async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                swl_test_core_request_recording_begin()
                defer { swl_test_core_request_recording_end() }

                let surface = try testSurface(pointer: 0x5B01)
                defer { surface.destroy() }
                var runtime = try configuredRuntime()
                let unusedBuffer = try testSurfaceBuffer(pointer: 0x5B02)
                let preparedCommit = try preparedCommit(
                    surface: surface,
                    runtime: &runtime,
                    constraints: .default,
                    payload: .metadataOnly
                )

                #expect(!preparedCommit.payload.attachesBuffer)
                _ = unusedBuffer
                _ = try SurfaceFrameCommitter.commit(preparedCommit, runtime: &runtime)

                let record = unsafe swl_test_core_request_record()
                #expect(unsafe record.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(unsafe record.attach_sequence == 0)
            }
        }
    }

    private func configuredRuntime() throws -> SurfaceRuntime<RoleToken> {
        var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
        runtime.recordConfigureReceived(serial: 7)
        try runtime.acknowledgeConfigure(serial: 7)
        try runtime.requestFrameCallback(generation: 1)
        return runtime
    }

    private func preparedCommit(
        surface: RawSurface,
        runtime: inout SurfaceRuntime<RoleToken>,
        constraints: SurfaceSubmitConstraints,
        payload: SurfaceCommitPayload
    ) throws -> PreparedSurfaceFrameCommit {
        try SurfaceFrameCommitter.prepare(
            SurfaceFrameCommitRequest(
                surface: surface,
                scaleInstallation: SurfaceScaleInstallation(),
                generation: 1,
                geometry: try testSurfaceGeometry(),
                payload: payload,
                submitConstraints: constraints
            ),
            runtime: &runtime,
        )
    }

    private func explicitConstraints(
        timeline: UInt64,
        acquire: UInt64,
        release: UInt64
    ) -> SurfaceSubmitConstraints {
        let identity = SurfaceSyncTimelineIdentity(timeline)
        return SurfaceSubmitConstraints(
            synchronization: .explicit(
                acquire: SurfaceSyncPoint(
                    timeline: identity,
                    point: RawSyncobjTimelinePoint(acquire)
                ),
                release: SurfaceSyncPoint(
                    timeline: identity,
                    point: RawSyncobjTimelinePoint(release)
                )
            ),
            pacing: .none
        )
    }

    private func testSurfaceGeometry() throws -> SurfaceGeometry {
        try SurfaceGeometry(
            logicalSize: PositiveLogicalSize(width: 80, height: 60),
            scale: .one
        )
    }

    private func testSurface(pointer rawPointer: UInt, version: RawVersion = 2) throws
        -> RawSurface
    {
        let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))
        let queuePointer = try unsafe #require(OpaquePointer(bitPattern: 0x5001))
        let eventQueue = RawEventQueue.testingQueueWithoutDestroy(opaquePointer: queuePointer)
        let proxyAdoption = RawProxyAdoptionContext(eventQueue: eventQueue)

        return try RawSurface.testingSurface(
            pointer: pointer,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }

    private func testSurfaceBuffer(pointer rawPointer: UInt) throws -> RawSurfaceBuffer {
        RawSurfaceBuffer(
            pointer: try unsafe #require(OpaquePointer(bitPattern: rawPointer))
        )
    }

    private final class StubSyncobjSurface {
        let object: RawLinuxDrmSyncobjSurface

        init() throws {
            let pointer = try unsafe #require(OpaquePointer(bitPattern: 0x5501))
            object = RawLinuxDrmSyncobjSurface(pointer: pointer) { pointer in
                unsafe _ = pointer
            }
        }
    }

// swiftlint:enable closure_body_length
#endif
