#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandRaw
    import WaylandTestSupport

    @testable import WaylandClient

    @Suite
    struct WindowSoftwarePresentationCommitSequenceTests {
        @Test(arguments: ManagedPresentationOperation.allCases)
        func managedSubmissionRequestsPresentationFeedbackBeforeCommit(
            operation: ManagedPresentationOperation
        ) throws {
            var events: [CommitSequenceEvent] = []
            let identity = SurfacePresentationIdentity(rawValue: 7)

            let returnedIdentity = try WindowSoftwarePresentationCommitSequence.perform {
                events.append(.frameCallback)
            } requestPresentationFeedback: {
                events.append(.presentationFeedback(operation))
                return identity
            } commit: {
                events.append(.commit(operation))
            } cancelFrameCallback: {
                events.append(.cancelFrameCallback)
            } cleanupAfterFailure: { identity in
                if let identity {
                    events.append(.cancelPresentationFeedback(identity))
                }
                events.append(.discardDrawingBuffer)
            }

            #expect(returnedIdentity == identity)
            #expect(
                events == [
                    .frameCallback,
                    .presentationFeedback(operation),
                    .commit(operation),
                ]
            )
        }

        @Test
        func presentationFeedbackRequestFailureDoesNotCommitFrame() {
            var events: [CommitSequenceEvent] = []

            do {
                try WindowSoftwarePresentationCommitSequence.perform {
                    events.append(.frameCallback)
                } requestPresentationFeedback: {
                    events.append(.presentationFeedback(.show))
                    throw InjectedPresentationFeedbackFailure()
                } commit: {
                    events.append(.commit(.show))
                } cancelFrameCallback: {
                    events.append(.cancelFrameCallback)
                } cleanupAfterFailure: { identity in
                    if let identity {
                        events.append(.cancelPresentationFeedback(identity))
                    }
                    events.append(.discardDrawingBuffer)
                }
                Issue.record("expected presentation feedback request failure")
            } catch is InjectedPresentationFeedbackFailure {
                #expect(
                    events == [
                        .frameCallback,
                        .presentationFeedback(.show),
                        .cancelFrameCallback,
                        .discardDrawingBuffer,
                    ]
                )
            } catch {
                Issue.record("unexpected error: \(error)")
            }
        }

        @Test
        func commitFailureCancelsPresentationFeedback() {
            var events: [CommitSequenceEvent] = []
            let identity = SurfacePresentationIdentity(rawValue: 9)

            do {
                try WindowSoftwarePresentationCommitSequence.perform {
                    events.append(.frameCallback)
                } requestPresentationFeedback: {
                    events.append(.presentationFeedback(.redraw))
                    return identity
                } commit: {
                    events.append(.commit(.redraw))
                    throw InjectedCommitFailure()
                } cancelFrameCallback: {
                    events.append(.cancelFrameCallback)
                } cleanupAfterFailure: { cancelledIdentity in
                    if let cancelledIdentity {
                        events.append(.cancelPresentationFeedback(cancelledIdentity))
                    }
                    events.append(.discardDrawingBuffer)
                }
                Issue.record("expected commit failure")
            } catch is InjectedCommitFailure {
                #expect(
                    events == [
                        .frameCallback,
                        .presentationFeedback(.redraw),
                        .commit(.redraw),
                        .cancelFrameCallback,
                        .cancelPresentationFeedback(identity),
                        .discardDrawingBuffer,
                    ]
                )
            } catch {
                Issue.record("unexpected error: \(error)")
            }
        }
    }

    @Suite(.serialized)
    struct WindowSoftwarePresenterTests {
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

        private func softwarePresentationContext() throws
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
                submitConstraints: .default,
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
        case frameCallback
        case presentationFeedback(ManagedPresentationOperation)
        case commit(ManagedPresentationOperation)
        case cancelFrameCallback
        case cancelPresentationFeedback(SurfacePresentationIdentity)
        case discardDrawingBuffer
    }

    private struct InjectedPresentationFeedbackFailure: Error {}
    private struct InjectedCommitFailure: Error {}
    private struct InjectedDrawFailure: Error {}
#endif
