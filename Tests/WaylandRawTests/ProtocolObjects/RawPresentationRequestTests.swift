#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @testable import WaylandRaw

    @Suite(.serialized)
    struct RawPresentationRequestTests {
        @Test
        func requestPresentationFeedbackCreatesFeedbackBeforeCommit() async throws {
            try await withPresentationRequestAndListenerRecording {
                let surface = try testSurface(pointer: 0xA101)
                defer { surface.destroy() }
                let presentation = try testPresentation(pointer: 0xA102)
                defer { presentation.destroy() }

                let feedback = try presentation.requestFeedback(for: surface) { _ in
                    _ = ()
                }
                defer { feedback.cancel() }
                surface.commit()

                let presentationRecord = unsafe swl_test_presentation_request_record()
                #expect(unsafe presentationRecord.call_count == 1)
                #expect(
                    unsafe presentationRecord.kind == SWL_TEST_PRESENTATION_FEEDBACK
                )
                #expect(
                    unsafe presentationRecord.object
                        == UnsafeMutableRawPointer(bitPattern: 0xA102)
                )
                #expect(
                    unsafe presentationRecord.surface
                        == UnsafeMutableRawPointer(bitPattern: 0xA101)
                )
                #expect(
                    unsafe presentationRecord.feedback
                        == UnsafeMutableRawPointer(bitPattern: 0xA601)
                )

                let coreRecord = unsafe swl_test_core_request_record()
                #expect(unsafe coreRecord.kind == SWL_TEST_CORE_SURFACE_COMMIT)
                #expect(unsafe coreRecord.commit_sequence > 0)
            }
        }

        @Test
        func presentedFeedbackPublishesTerminalEvent() async throws {
            try await withPresentationListenerRecording {
                var events: [RawPresentationFeedbackEvent] = []
                let outputPointer = try unsafe testPointer(0xA202)
                let feedback = try testPresentationFeedback(pointer: 0xA201) { event in
                    events.append(event)
                }
                defer { feedback.cancel() }

                #expect(
                    unsafe swl_test_presentation_feedback_listener_emit_sync_output(
                        outputPointer
                    ) == 1
                )
                #expect(
                    swl_test_presentation_feedback_listener_emit_presented(
                        1,
                        2,
                        3,
                        4,
                        5,
                        6,
                        0x9
                    ) == 1
                )

                let expectedEvent = unsafe expectedPresentedEvent(
                    outputPointer: outputPointer
                )
                #expect(events == [expectedEvent])
            }
        }

        @Test
        func discardedFeedbackPublishesTerminalEvent() async throws {
            try await withPresentationListenerRecording {
                var events: [RawPresentationFeedbackEvent] = []
                let feedback = try testPresentationFeedback(pointer: 0xA301) { event in
                    events.append(event)
                }
                defer { feedback.cancel() }

                #expect(swl_test_presentation_feedback_listener_emit_discarded() == 1)
                #expect(events == [.discarded])
            }
        }
    }

    private func withPresentationRequestAndListenerRecording(
        _ operation: () throws -> Void
    ) async throws {
        try await CoreRequestRecordingGate.withExclusiveRecording {
            try await PresentationRequestRecordingGate.withExclusiveRecording {
                try await PresentationListenerRecordingGate.withExclusiveRecording {
                    swl_test_core_request_recording_begin()
                    swl_test_presentation_request_recording_begin()
                    swl_test_presentation_listener_recording_begin()
                    defer { swl_test_presentation_listener_recording_end() }
                    defer { swl_test_presentation_request_recording_end() }
                    defer { swl_test_core_request_recording_end() }
                    try operation()
                }
            }
        }
    }

    private func withPresentationListenerRecording(
        _ operation: () throws -> Void
    ) async throws {
        try await PresentationListenerRecordingGate.withExclusiveRecording {
            swl_test_presentation_listener_recording_begin()
            defer { swl_test_presentation_listener_recording_end() }
            try operation()
        }
    }

    private func testPresentation(pointer rawPointer: UInt) throws -> RawPresentation {
        try unsafe RawPresentation(
            pointer: testPointer(rawPointer),
            version: 1,
            proxyAdoption: try testAdoptionContext()
        )
    }

    private func testPresentationFeedback(
        pointer rawPointer: UInt,
        events: @escaping (RawPresentationFeedbackEvent) -> Void
    ) throws -> RawPresentationFeedback {
        try unsafe RawPresentationFeedback(
            pointer: testPointer(rawPointer),
            invariantFailureSink: nil,
            onEvent: events
        )
    }

    private func expectedPresentedEvent(
        outputPointer: OpaquePointer
    ) -> RawPresentationFeedbackEvent {
        .presented(
            RawPresentationPresented(
                timestamp: RawPresentationTimestamp(tvSecHi: 1, tvSecLo: 2, tvNsec: 3),
                refreshNanoseconds: 4,
                sequence: RawPresentationSequence(seqHi: 5, seqLo: 6),
                flags: 0x9,
                synchronizedOutput: RawOutputPointerIdentity(outputPointer)
            )
        )
    }

#endif
