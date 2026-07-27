#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandRaw
    import WaylandTestSupport

    @testable import WaylandClient

    @Suite
    struct WindowSoftwarePresentationCommitSequenceTests {
        @Test(arguments: ManagedPresentationOperation.allCases)
        func pointOfNoReturnMarksBufferBusyBeforeProtocolRequests(
            operation: ManagedPresentationOperation
        ) {
            var events: [CommitSequenceEvent] = []
            let identity = SurfacePresentationIdentity(rawValue: 7)

            let returnedIdentity = WindowSoftwarePresentationCommitSequence.perform(
                stageSuccess: {
                    events.append(.stageSuccess)
                },
                markDrawingBufferBusy: {
                    events.append(.markDrawingBufferBusy)
                },
                requestFrameCallback: {
                    events.append(.frameCallback)
                },
                requestPresentationFeedback: {
                    events.append(.presentationFeedback(operation))
                    return identity
                },
                commit: {
                    events.append(.commit(operation))
                }
            )

            #expect(returnedIdentity == identity)
            #expect(
                events == [
                    .stageSuccess,
                    .markDrawingBufferBusy,
                    .frameCallback,
                    .presentationFeedback(operation),
                    .commit(operation),
                ]
            )
        }

        @Test
        func successStagingFailureStopsBeforePointOfNoReturn() {
            var events: [CommitSequenceEvent] = []

            do {
                _ = try WindowSoftwarePresentationCommitSequence.perform(
                    stageSuccess: {
                        events.append(.stageSuccess)
                        throw InjectedSuccessStagingFailure()
                    },
                    markDrawingBufferBusy: {
                        events.append(.markDrawingBufferBusy)
                    },
                    requestFrameCallback: {
                        events.append(.frameCallback)
                    },
                    requestPresentationFeedback: {
                        events.append(.presentationFeedback(.redraw))
                        return nil
                    },
                    commit: {
                        events.append(.commit(.redraw))
                    }
                )
                Issue.record("expected success staging failure")
            } catch is InjectedSuccessStagingFailure {
                // The injected failure must remain observable before the point of no return.
            } catch {
                Issue.record("unexpected error: \(error)")
            }

            #expect(events == [.stageSuccess])
        }
    }

    @Suite(.serialized)
    struct WindowSoftwarePresenterTests {  // swiftlint:disable:this type_body_length
        private struct RoleToken {}
        private struct FrameIDCaptureComplete: Error {}

        @Test
        func drawFailureWrapsOriginalCauseBeforePresentationRequests() async throws {
            try await withSoftwarePresentationRecording {
                try exerciseDrawFailureBeforePresentationRequests()
            }
        }

        @Test
        func bufferIDsAreUniqueAcrossPoolAllocations() async throws {
            try await withSoftwarePresentationRecording {
                let surface = try testSurface(pointer: 0x6A11)
                let sharedMemory = try testSharedMemory(pointer: 0x6A12)

                let firstID = try renderSoftwareFrameID(
                    surface: surface,
                    pool: try sharedMemory.createPool(width: 64, height: 48, bufferCount: 1)
                )
                let secondID = try renderSoftwareFrameID(
                    surface: surface,
                    pool: try sharedMemory.createPool(width: 64, height: 48, bufferCount: 1)
                )

                #expect(firstID != secondID)
            }
        }

        @Test
        func reservedBufferCanBeDiscardedAfterPoolRetirement() async throws {
            try await withSoftwarePresentationRecording {
                let sharedMemory = try testSharedMemory(pointer: 0x6A22)
                let pool = try sharedMemory.createPool(width: 64, height: 48, bufferCount: 1)
                let reservedBuffer = try #require(pool.acquireReservedDrawingBuffer())

                pool.retire(reason: .resized)
                #expect(unsafe swl_test_core_request_record().buffer_destroy_sequence == 0)

                reservedBuffer.discard()
                #expect(unsafe swl_test_core_request_record().buffer_destroy_sequence == 0)
                #expect(!pool.hasBusyBuffers)
                #expect(!pool.hasFreeBuffers)

                pool.destroy()
                #expect(unsafe swl_test_core_request_record().buffer_destroy_sequence > 0)
                #expect(unsafe swl_test_core_request_record().shm_pool_destroy_sequence > 0)
            }
        }

        @Test
        func submitConstraintFailureLeavesDrawingBufferReusable() async throws {
            try await withSoftwarePresentationRecording {
                try exerciseSubmitConstraintFailureLeavesDrawingBufferReusable()
            }
        }

        @Test
        func successStagingFailureLeavesDrawingBufferReusable() async throws {
            try await withSoftwarePresentationRecording {
                try exerciseSuccessStagingFailureLeavesDrawingBufferReusable()
            }
        }

        private func exerciseSuccessStagingFailureLeavesDrawingBufferReusable() throws {
            let surface = try testSurface(pointer: 0x6A41)
            let sharedMemory = try testSharedMemory(pointer: 0x6A42)
            let pool = try sharedMemory.createPool(width: 64, height: 48, bufferCount: 1)
            var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
            runtime.recordConfigureReceived(serial: 1)
            try runtime.acknowledgeConfigure(serial: 1)
            var pendingFrameRegistration: FrameCallbackRegistration?
            let presenter = softwarePresenter(surface: surface, pool: pool)

            do {
                _ = try presenter.present(
                    context: try softwarePresentationContext(),
                    draw: { _ in () },
                    stageSuccess: { currentBufferAvailability in
                        #expect(currentBufferAvailability == .unavailable)
                        throw InjectedSuccessStagingFailure()
                    },
                    runtime: &runtime,
                    pendingFrameRegistration: &pendingFrameRegistration
                )
                Issue.record("expected success staging failure")
            } catch is InjectedSuccessStagingFailure {
                // Success bookkeeping remains fallible only before the point of no return.
            } catch {
                Issue.record("unexpected error: \(error)")
            }

            let hasPendingRegistration = hasPendingFrameRegistration(pendingFrameRegistration)
            #expect(!hasPendingRegistration)
            #expect(!pool.hasBusyBuffers)
            #expect(pool.hasFreeBuffers)
            #expect(unsafe swl_test_core_request_record().frame_sequence == 0)
            #expect(unsafe swl_test_core_request_record().attach_sequence == 0)
            #expect(unsafe swl_test_core_request_record().damage_sequence == 0)
            #expect(unsafe swl_test_presentation_request_record().call_count == 0)
            #expect(unsafe swl_test_core_request_record().commit_sequence == 0)
        }

        private func exerciseSubmitConstraintFailureLeavesDrawingBufferReusable() throws {
            let surface = try testSurface(pointer: 0x6A31)
            let sharedMemory = try testSharedMemory(pointer: 0x6A32)
            let pool = try sharedMemory.createPool(width: 64, height: 48, bufferCount: 1)
            let acquirePoint = SurfaceSyncPoint(
                timeline: SurfaceSyncTimelineIdentity(77),
                point: RawSyncobjTimelinePoint(2)
            )
            let releasePoint = SurfaceSyncPoint(
                timeline: SurfaceSyncTimelineIdentity(77),
                point: RawSyncobjTimelinePoint(3)
            )
            var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
            runtime.setExplicitSynchronizationActive()
            runtime.recordConfigureReceived(serial: 1)
            try runtime.acknowledgeConfigure(serial: 1)
            var pendingFrameRegistration: FrameCallbackRegistration?
            let presenter = softwarePresenter(surface: surface, pool: pool)

            do {
                _ = try presenter.present(
                    context: try softwarePresentationContext(
                        submitConstraints: SurfaceSubmitConstraints(
                            synchronization: .explicit(
                                acquire: acquirePoint,
                                release: releasePoint
                            ),
                            pacing: .none
                        )
                    ),
                    draw: { _ in () },
                    runtime: &runtime,
                    pendingFrameRegistration: &pendingFrameRegistration
                )
                Issue.record("expected submit constraint failure")
            } catch let failure as WindowSoftwarePresentationFailure {
                #expect(
                    failure.underlying as? SurfaceSubmitConstraintError
                        == .explicitSyncUnavailable
                )
            } catch {
                Issue.record("unexpected error: \(error)")
            }

            let hasPendingRegistration = hasPendingFrameRegistration(pendingFrameRegistration)
            #expect(!hasPendingRegistration)
            #expect(!pool.hasBusyBuffers)
            #expect(pool.hasFreeBuffers)
            #expect(unsafe swl_test_core_request_record().frame_sequence == 0)
            #expect(unsafe swl_test_core_request_record().attach_sequence == 0)
            #expect(unsafe swl_test_core_request_record().damage_sequence == 0)
            #expect(unsafe swl_test_presentation_request_record().call_count == 0)
            #expect(unsafe swl_test_core_request_record().commit_sequence == 0)
        }

        private func exerciseDrawFailureBeforePresentationRequests() throws {
            let surface = try testSurface(pointer: 0x6A01)
            let sharedMemory = try testSharedMemory(pointer: 0x6A02)
            let pool = try sharedMemory.createPool(width: 64, height: 48, bufferCount: 1)
            var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
            var pendingFrameRegistration: FrameCallbackRegistration?
            let presenter = softwarePresenter(surface: surface, pool: pool)

            do {
                _ = try presenter.present(
                    context: try softwarePresentationContext(),
                    draw: { _ in
                        throw InjectedDrawFailure()
                    },
                    runtime: &runtime,
                    pendingFrameRegistration: &pendingFrameRegistration
                )
                Issue.record("expected draw failure")
            } catch let failure as WindowSoftwarePresentationFailure {
                #expect(failure.underlying is InjectedDrawFailure)
                guard case .userDraw = failure.presentationError else {
                    Issue.record("expected user draw presentation error")
                    return
                }
            } catch {
                Issue.record("unexpected error: \(error)")
            }

            #expect(unsafe swl_test_presentation_request_record().call_count == 0)
            #expect(unsafe swl_test_core_request_record().commit_sequence == 0)
        }

        private func renderSoftwareFrameID(
            surface: RawSurface,
            pool: RawSharedMemoryPool
        ) throws -> SoftwareFrameBufferID {
            var runtime = SurfaceRuntime<RoleToken>(role: .toplevelWindow)
            var pendingFrameRegistration: FrameCallbackRegistration?
            let presenter = softwarePresenter(surface: surface, pool: pool)
            var capturedID: SoftwareFrameBufferID?

            do {
                _ = try presenter.present(
                    context: try softwarePresentationContext(),
                    draw: { frame in
                        capturedID = frame.id
                        throw FrameIDCaptureComplete()
                    },
                    runtime: &runtime,
                    pendingFrameRegistration: &pendingFrameRegistration
                )
                Issue.record("expected frame ID capture to stop drawing")
            } catch let failure as WindowSoftwarePresentationFailure
                where failure.underlying is FrameIDCaptureComplete
            {
                // Capturing the ID during draw is enough for this identity regression.
            } catch {
                throw error
            }

            return try #require(capturedID)
        }

        private func withSoftwarePresentationRecording(
            _ operation: () throws -> Void
        ) async throws {
            try await CoreRequestRecordingGate.withExclusiveRecording {
                try await PresentationRequestRecordingGate.withExclusiveRecording {
                    swl_test_core_request_recording_begin()
                    swl_test_presentation_request_recording_begin()
                    swl_test_buffer_listener_recording_begin()
                    defer { swl_test_buffer_listener_recording_end() }
                    defer { swl_test_presentation_request_recording_end() }
                    defer { swl_test_core_request_recording_end() }
                    try operation()
                }
            }
        }

        private func hasPendingFrameRegistration(
            _ registration: borrowing FrameCallbackRegistration?
        ) -> Bool {
            switch registration {
            case .some: true
            case .none: false
            }
        }

        private func softwarePresentationContext(
            submitConstraints: SurfaceSubmitConstraints = .default
        ) throws
            -> WindowSoftwarePresentationContext
        {
            let geometry = try SurfaceGeometry(
                logicalSize: PositiveLogicalSize(width: 64, height: 48),
                scale: .one
            )
            let configure = try WindowConfigureEvent(
                sequence: XDGConfigureSequence(
                    serial: 1,
                    topLevel: XDGTopLevelConfigureSuggestion(
                        size: TopLevelSize(width: 64, height: 48)
                    )
                ),
                previousSize: nil,
                fallbackSize: .default
            )
            return WindowSoftwarePresentationContext(
                request: PresentationRequest(
                    generation: 1,
                    configuration: configure.configuration
                ),
                geometry: geometry,
                submitConstraints: submitConstraints,
                metadata: .default,
                damage: nil,
                presentationFeedback: nil
            )
        }

        private func softwarePresenter(
            surface: RawSurface,
            pool: RawSharedMemoryPool
        ) -> WindowSoftwarePresenter {
            WindowSoftwarePresenter(
                surface: surface,
                scaleInstallation: SurfaceScaleInstallation(),
                createSharedMemoryPool: { _ in pool },
                isWindowClosed: { false },
                onFrame: {
                    _ = ()
                }
            )
        }

        private func testSurface(pointer rawPointer: UInt) throws -> RawSurface {
            let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))
            return try RawSurface.testingSurface(
                pointer: pointer,
                version: 4,
                proxyAdoption: try testAdoptionContext()
            )
        }

        private func testSharedMemory(pointer rawPointer: UInt) throws -> RawSharedMemory {
            let pointer = try unsafe #require(OpaquePointer(bitPattern: rawPointer))
            return try RawSharedMemory.testingSharedMemory(
                pointer: pointer,
                version: 1,
                proxyAdoption: try testAdoptionContext()
            )
        }

        private func testAdoptionContext() throws -> RawProxyAdoptionContext {
            let pointer = try unsafe #require(OpaquePointer(bitPattern: 0x6A03))
            return RawProxyAdoptionContext(
                eventQueue: RawEventQueue.testingQueueWithoutDestroy(
                    opaquePointer: pointer
                )
            )
        }
    }

    enum ManagedPresentationOperation: CaseIterable, Sendable {
        case show
        case redraw
    }

    private enum CommitSequenceEvent: Equatable {
        case stageSuccess
        case markDrawingBufferBusy
        case frameCallback
        case presentationFeedback(ManagedPresentationOperation)
        case commit(ManagedPresentationOperation)
    }

    private struct InjectedDrawFailure: Error {}
    private struct InjectedSuccessStagingFailure: Error {}
#endif
