#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @Suite(.serialized)
    struct SyncobjShimContractTests {
        @Test
        func syncobjGetSurfaceUsesManagerAndSurface() async throws {
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xD001))
            let surface = try unsafe #require(OpaquePointer(bitPattern: 0xD002))

            try await assertSyncobjRequest(
                expectedKind: SWL_TEST_SYNCOBJ_GET_SURFACE,
                object: manager
            ) {
                let syncobjSurface = unsafe swl_wp_linux_drm_syncobj_manager_v1_get_surface(
                    manager,
                    surface
                )
                #expect(unsafe syncobjSurface != nil)
                let record = unsafe swl_test_syncobj_request_record()
                #expect(unsafe record.surface == UnsafeMutableRawPointer(surface))
            }
        }

        @Test
        func syncobjImportTimelinePreservesFileDescriptor() async throws {
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xD003))

            try await assertSyncobjRequest(
                expectedKind: SWL_TEST_SYNCOBJ_IMPORT_TIMELINE,
                object: manager
            ) {
                let timeline = unsafe swl_wp_linux_drm_syncobj_manager_v1_import_timeline(
                    manager,
                    77
                )
                #expect(unsafe timeline != nil)
                let record = unsafe swl_test_syncobj_request_record()
                #expect(unsafe record.fd == 77)
            }
        }

        @Test
        func syncobjSetPointsPreserveTimelineAndPointBits() async throws {
            let syncobjSurface = try unsafe #require(OpaquePointer(bitPattern: 0xD004))
            let timeline = try unsafe #require(OpaquePointer(bitPattern: 0xD005))

            try await assertSyncobjRequest(
                expectedKind: SWL_TEST_SYNCOBJ_SET_ACQUIRE_POINT,
                object: syncobjSurface
            ) {
                unsafe swl_wp_linux_drm_syncobj_surface_v1_set_acquire_point(
                    syncobjSurface,
                    timeline,
                    0x1122_3344,
                    0x5566_7788
                )
                let record = unsafe swl_test_syncobj_request_record()
                #expect(unsafe record.timeline == UnsafeMutableRawPointer(timeline))
                #expect(unsafe record.point_hi == 0x1122_3344)
                #expect(unsafe record.point_lo == 0x5566_7788)
            }

            try await assertSyncobjRequest(
                expectedKind: SWL_TEST_SYNCOBJ_SET_RELEASE_POINT,
                object: syncobjSurface
            ) {
                unsafe swl_wp_linux_drm_syncobj_surface_v1_set_release_point(
                    syncobjSurface,
                    timeline,
                    0xAABB_CCDD,
                    0xEEFF_0011
                )
                let record = unsafe swl_test_syncobj_request_record()
                #expect(unsafe record.timeline == UnsafeMutableRawPointer(timeline))
                #expect(unsafe record.point_hi == 0xAABB_CCDD)
                #expect(unsafe record.point_lo == 0xEEFF_0011)
            }
        }

        @Test
        func syncobjDestroyUsesMatchingTargets() async throws {
            let syncobjSurface = try unsafe #require(OpaquePointer(bitPattern: 0xD006))
            let timeline = try unsafe #require(OpaquePointer(bitPattern: 0xD007))
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xD008))

            try await assertSyncobjDestroy(
                expectedKind: SWL_TEST_SYNCOBJ_DESTROY_SURFACE,
                object: syncobjSurface
            ) {
                unsafe swl_wp_linux_drm_syncobj_surface_v1_destroy(syncobjSurface)
            }
            try await assertSyncobjDestroy(
                expectedKind: SWL_TEST_SYNCOBJ_DESTROY_TIMELINE,
                object: timeline
            ) {
                unsafe swl_wp_linux_drm_syncobj_timeline_v1_destroy(timeline)
            }
            try await assertSyncobjDestroy(
                expectedKind: SWL_TEST_SYNCOBJ_DESTROY_MANAGER,
                object: manager
            ) {
                unsafe swl_wp_linux_drm_syncobj_manager_v1_destroy(manager)
            }
        }

        @safe
        private func assertSyncobjRequest(
            expectedKind: swl_test_syncobj_request_kind,
            object rawObject: OpaquePointer?,
            request: () -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let object = unsafe UnsafeMutableRawPointer(rawObject)
            try await SyncobjRequestRecordingGate.withExclusiveRecording {
                swl_test_syncobj_request_recording_begin()
                defer { swl_test_syncobj_request_recording_end() }

                request()

                let record = unsafe swl_test_syncobj_request_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.object == object, sourceLocation: sourceLocation)
            }
        }

        @safe
        private func assertSyncobjDestroy(
            expectedKind: swl_test_syncobj_destroy_kind,
            object rawObject: OpaquePointer?,
            request: () -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let object = unsafe UnsafeMutableRawPointer(rawObject)
            try await SyncobjRequestRecordingGate.withExclusiveRecording {
                swl_test_syncobj_request_recording_begin()
                defer { swl_test_syncobj_request_recording_end() }

                request()

                let record = unsafe swl_test_syncobj_destroy_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.object == object, sourceLocation: sourceLocation)
            }
        }
    }
    @Suite(.serialized)
    struct FifoShimContractTests {
        @Test
        func fifoGetSurfaceAndRequestsUseExpectedTargets() async throws {
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xF001))
            let surface = try unsafe #require(OpaquePointer(bitPattern: 0xF002))
            let fifo = try unsafe #require(OpaquePointer(bitPattern: 0xF003))

            try await assertFifoRequest(
                expectedKind: SWL_TEST_FIFO_GET_FIFO,
                object: manager
            ) {
                let createdFifo = unsafe swl_wp_fifo_manager_v1_get_fifo(manager, surface)
                #expect(unsafe createdFifo != nil)
                let record = unsafe swl_test_fifo_request_record()
                #expect(unsafe record.surface == UnsafeMutableRawPointer(surface))
            }

            try await assertFifoRequest(
                expectedKind: SWL_TEST_FIFO_SET_BARRIER,
                object: fifo
            ) {
                unsafe swl_wp_fifo_v1_set_barrier(fifo)
            }

            try await assertFifoRequest(
                expectedKind: SWL_TEST_FIFO_WAIT_BARRIER,
                object: fifo
            ) {
                unsafe swl_wp_fifo_v1_wait_barrier(fifo)
            }
        }

        @Test
        func fifoDestroyUsesMatchingTargets() async throws {
            let fifo = try unsafe #require(OpaquePointer(bitPattern: 0xF004))
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xF005))

            try await assertFifoDestroy(
                expectedKind: SWL_TEST_FIFO_DESTROY_FIFO,
                object: fifo
            ) {
                unsafe swl_wp_fifo_v1_destroy(fifo)
            }
            try await assertFifoDestroy(
                expectedKind: SWL_TEST_FIFO_DESTROY_MANAGER,
                object: manager
            ) {
                unsafe swl_wp_fifo_manager_v1_destroy(manager)
            }
        }

        @safe
        private func assertFifoRequest(
            expectedKind: swl_test_fifo_request_kind,
            object rawObject: OpaquePointer?,
            request: () -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let object = unsafe UnsafeMutableRawPointer(rawObject)
            try await FifoRequestRecordingGate.withExclusiveRecording {
                swl_test_fifo_request_recording_begin()
                defer { swl_test_fifo_request_recording_end() }

                request()

                let record = unsafe swl_test_fifo_request_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.object == object, sourceLocation: sourceLocation)
            }
        }

        @safe
        private func assertFifoDestroy(
            expectedKind: swl_test_fifo_destroy_kind,
            object rawObject: OpaquePointer?,
            request: () -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let object = unsafe UnsafeMutableRawPointer(rawObject)
            try await FifoRequestRecordingGate.withExclusiveRecording {
                swl_test_fifo_request_recording_begin()
                defer { swl_test_fifo_request_recording_end() }

                request()

                let record = unsafe swl_test_fifo_destroy_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.object == object, sourceLocation: sourceLocation)
            }
        }
    }

    @Suite(.serialized)
    struct CommitTimingShimContractTests {
        @Test
        func commitTimingGetTimerAndTimestampPreserveArguments() async throws {
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xC001))
            let surface = try unsafe #require(OpaquePointer(bitPattern: 0xC002))
            let timer = try unsafe #require(OpaquePointer(bitPattern: 0xC003))

            try await assertCommitTimingRequest(
                expectedKind: SWL_TEST_COMMIT_TIMING_GET_TIMER,
                object: manager
            ) {
                let createdTimer = unsafe swl_wp_commit_timing_manager_v1_get_timer(
                    manager,
                    surface
                )
                #expect(unsafe createdTimer != nil)
                let record = unsafe swl_test_commit_timing_request_record()
                #expect(unsafe record.surface == UnsafeMutableRawPointer(surface))
            }

            try await assertCommitTimingRequest(
                expectedKind: SWL_TEST_COMMIT_TIMING_SET_TIMESTAMP,
                object: timer
            ) {
                unsafe swl_wp_commit_timer_v1_set_timestamp(
                    timer,
                    0x1122_3344,
                    0x5566_7788,
                    999_999_999
                )
                let record = unsafe swl_test_commit_timing_request_record()
                #expect(unsafe record.tv_sec_hi == 0x1122_3344)
                #expect(unsafe record.tv_sec_lo == 0x5566_7788)
                #expect(unsafe record.tv_nsec == 999_999_999)
            }
        }

        @Test
        func commitTimingDestroyUsesMatchingTargets() async throws {
            let timer = try unsafe #require(OpaquePointer(bitPattern: 0xC004))
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xC005))

            try await assertCommitTimingDestroy(
                expectedKind: SWL_TEST_COMMIT_TIMING_DESTROY_TIMER,
                object: timer
            ) {
                unsafe swl_wp_commit_timer_v1_destroy(timer)
            }
            try await assertCommitTimingDestroy(
                expectedKind: SWL_TEST_COMMIT_TIMING_DESTROY_MANAGER,
                object: manager
            ) {
                unsafe swl_wp_commit_timing_manager_v1_destroy(manager)
            }
        }

        @safe
        private func assertCommitTimingRequest(
            expectedKind: swl_test_commit_timing_request_kind,
            object rawObject: OpaquePointer?,
            request: () -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let object = unsafe UnsafeMutableRawPointer(rawObject)
            try await CommitTimingRequestRecordingGate.withExclusiveRecording {
                swl_test_commit_timing_request_recording_begin()
                defer { swl_test_commit_timing_request_recording_end() }

                request()

                let record = unsafe swl_test_commit_timing_request_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.object == object, sourceLocation: sourceLocation)
            }
        }

        @safe
        private func assertCommitTimingDestroy(
            expectedKind: swl_test_commit_timing_destroy_kind,
            object rawObject: OpaquePointer?,
            request: () -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let object = unsafe UnsafeMutableRawPointer(rawObject)
            try await CommitTimingRequestRecordingGate.withExclusiveRecording {
                swl_test_commit_timing_request_recording_begin()
                defer { swl_test_commit_timing_request_recording_end() }

                request()

                let record = unsafe swl_test_commit_timing_destroy_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.object == object, sourceLocation: sourceLocation)
            }
        }
    }

#endif
