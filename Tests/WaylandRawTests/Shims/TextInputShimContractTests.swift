#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing
    import WaylandTestSupport

    @Suite(.serialized)
    struct TextInputShimContractTests {
        @Test
        func textInputGetTextInputUsesManagerAndSeat() async throws {
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0x1001))
            let seat = try unsafe #require(OpaquePointer(bitPattern: 0x2002))

            try await assertTextInputRequest(
                expectedKind: SWL_TEST_TEXT_INPUT_MANAGER_GET_TEXT_INPUT,
                object: manager
            ) {
                let textInput = unsafe swl_text_input_manager_v3_get_text_input(manager, seat)
                #expect(unsafe textInput != nil)
                let record = unsafe swl_test_text_input_request_record()
                #expect(unsafe record.seat == seat)
            }
        }

        @Test
        func textInputSetSurroundingTextPreservesTextCursorAndAnchor() async throws {
            let textInput = try unsafe #require(OpaquePointer(bitPattern: 0x3003))

            try await assertTextInputRequest(
                expectedKind: SWL_TEST_TEXT_INPUT_SET_SURROUNDING_TEXT,
                object: textInput
            ) {
                try unsafe "aé".withCString { text in
                    unsafe swl_text_input_v3_set_surrounding_text(
                        textInput,
                        text,
                        3,
                        1
                    )
                    let record = unsafe swl_test_text_input_request_record()
                    let recordedText = try unsafe #require(record.text)
                    #expect(unsafe String(cString: recordedText) == "aé")
                    #expect(unsafe record.cursor == 3)
                    #expect(unsafe record.anchor == 1)
                }
            }
        }

        @Test
        func textInputSetContentTypePreservesHintAndPurpose() async throws {
            let textInput = try unsafe #require(OpaquePointer(bitPattern: 0x4004))

            try await assertTextInputRequest(
                expectedKind: SWL_TEST_TEXT_INPUT_SET_CONTENT_TYPE,
                object: textInput
            ) {
                unsafe swl_text_input_v3_set_content_type(textInput, 0x101, 6)
                let record = unsafe swl_test_text_input_request_record()
                #expect(unsafe record.hint == 0x101)
                #expect(unsafe record.purpose == 6)
            }
        }

        @Test
        func textInputLifecycleRequestsUseTextInputTarget() async throws {
            let textInput = try unsafe #require(OpaquePointer(bitPattern: 0x5005))

            try await assertTextInputRequest(
                expectedKind: SWL_TEST_TEXT_INPUT_ENABLE,
                object: textInput
            ) {
                unsafe swl_text_input_v3_enable(textInput)
            }
            try await assertTextInputRequest(
                expectedKind: SWL_TEST_TEXT_INPUT_DISABLE,
                object: textInput
            ) {
                unsafe swl_text_input_v3_disable(textInput)
            }
            try await assertTextInputRequest(
                expectedKind: SWL_TEST_TEXT_INPUT_COMMIT,
                object: textInput
            ) {
                unsafe swl_text_input_v3_commit(textInput)
            }
            try await assertTextInputRequest(
                expectedKind: SWL_TEST_TEXT_INPUT_SHOW_INPUT_PANEL,
                object: textInput
            ) {
                unsafe swl_text_input_v3_show_input_panel(textInput)
            }
            try await assertTextInputRequest(
                expectedKind: SWL_TEST_TEXT_INPUT_HIDE_INPUT_PANEL,
                object: textInput
            ) {
                unsafe swl_text_input_v3_hide_input_panel(textInput)
            }
        }

        @Test
        func textInputListenerPublishesPayloads() throws {
            let data = unsafe UnsafeMutableRawPointer(bitPattern: 0x6006)
            let textInput = try unsafe #require(OpaquePointer(bitPattern: 0x7007))
            let surface = try unsafe #require(OpaquePointer(bitPattern: 0x8008))

            var enter = unsafe swl_test_text_input_listener_record()
            unsafe swl_test_text_input_listener_emit_enter(
                data,
                textInput,
                surface,
                &enter
            )
            #expect(unsafe enter.call_count == 1)
            #expect(unsafe enter.kind == SWL_TEST_TEXT_INPUT_LISTENER_ENTER)
            #expect(unsafe enter.data == data)
            #expect(unsafe enter.text_input == textInput)
            #expect(unsafe enter.surface == surface)

            try assertTextInputTextEvents(data: data, textInput: textInput)
            assertTextInputNumericEvents(data: data, textInput: textInput)
        }

        @Test
        func textInputDestroyWrappersUseMatchingTargets() async throws {
            let textInput = try unsafe #require(OpaquePointer(bitPattern: 0x9009))
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xA00A))

            try await assertTextInputDestroy(
                expectedKind: SWL_TEST_TEXT_INPUT_DESTROY_TEXT_INPUT,
                object: textInput
            ) {
                unsafe swl_text_input_v3_destroy(textInput)
            }
            try await assertTextInputDestroy(
                expectedKind: SWL_TEST_TEXT_INPUT_DESTROY_MANAGER,
                object: manager
            ) {
                unsafe swl_text_input_manager_v3_destroy(manager)
            }
        }

        @safe
        private func assertTextInputRequest(
            expectedKind: swl_test_text_input_request_kind,
            object rawObject: OpaquePointer?,
            request: () throws -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let object = unsafe UnsafeMutableRawPointer(rawObject)
            try await TextInputRequestRecordingGate.withExclusiveRecording {
                swl_test_text_input_request_recording_begin()
                defer { swl_test_text_input_request_recording_end() }

                try request()

                let record = unsafe swl_test_text_input_request_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.object == object, sourceLocation: sourceLocation)
            }
        }

        @safe
        private func assertTextInputDestroy(
            expectedKind: swl_test_text_input_destroy_kind,
            object rawObject: OpaquePointer?,
            request: () -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) async throws {
            let object = unsafe UnsafeMutableRawPointer(rawObject)
            try await TextInputRequestRecordingGate.withExclusiveRecording {
                swl_test_text_input_request_recording_begin()
                defer { swl_test_text_input_request_recording_end() }

                request()

                let record = unsafe swl_test_text_input_destroy_record()
                #expect(unsafe record.call_count == 1, sourceLocation: sourceLocation)
                #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
                #expect(unsafe record.object == object, sourceLocation: sourceLocation)
            }
        }
    }

    @safe
    private func assertTextInputTextEvents(
        data: UnsafeMutableRawPointer?,
        textInput: OpaquePointer
    ) throws {
        var preedit = unsafe swl_test_text_input_listener_record()
        try unsafe "compose".withCString { text in
            unsafe swl_test_text_input_listener_emit_preedit_string(
                data,
                textInput,
                text,
                2,
                4,
                &preedit
            )
            let recordedText = try unsafe #require(preedit.text)
            #expect(unsafe String(cString: recordedText) == "compose")
        }
        #expect(unsafe preedit.kind == SWL_TEST_TEXT_INPUT_LISTENER_PREEDIT_STRING)
        #expect(unsafe preedit.cursor_begin == 2)
        #expect(unsafe preedit.cursor_end == 4)

        var commit = unsafe swl_test_text_input_listener_record()
        try unsafe "é".withCString { text in
            unsafe swl_test_text_input_listener_emit_commit_string(
                data,
                textInput,
                text,
                &commit
            )
            let recordedText = try unsafe #require(commit.text)
            #expect(unsafe String(cString: recordedText) == "é")
        }
        #expect(unsafe commit.kind == SWL_TEST_TEXT_INPUT_LISTENER_COMMIT_STRING)

        var language = unsafe swl_test_text_input_listener_record()
        try unsafe "fr-CA".withCString { text in
            unsafe swl_test_text_input_listener_emit_language(
                data,
                textInput,
                text,
                &language
            )
            let recordedText = try unsafe #require(language.text)
            #expect(unsafe String(cString: recordedText) == "fr-CA")
        }
        #expect(unsafe language.kind == SWL_TEST_TEXT_INPUT_LISTENER_LANGUAGE)
    }

    @safe
    private func assertTextInputNumericEvents(
        data: UnsafeMutableRawPointer?,
        textInput: OpaquePointer
    ) {
        var deleted = unsafe swl_test_text_input_listener_record()
        unsafe swl_test_text_input_listener_emit_delete_surrounding_text(
            data,
            textInput,
            5,
            6,
            &deleted
        )
        #expect(
            unsafe deleted.kind == SWL_TEST_TEXT_INPUT_LISTENER_DELETE_SURROUNDING_TEXT
        )
        #expect(unsafe deleted.before_length == 5)
        #expect(unsafe deleted.after_length == 6)

        var done = unsafe swl_test_text_input_listener_record()
        unsafe swl_test_text_input_listener_emit_done(data, textInput, 44, &done)
        #expect(unsafe done.kind == SWL_TEST_TEXT_INPUT_LISTENER_DONE)
        #expect(unsafe done.serial == 44)

        var action = unsafe swl_test_text_input_listener_record()
        unsafe swl_test_text_input_listener_emit_action(
            data,
            textInput,
            99,
            45,
            &action
        )
        #expect(unsafe action.kind == SWL_TEST_TEXT_INPUT_LISTENER_ACTION)
        #expect(unsafe action.action == 99)
        #expect(unsafe action.serial == 45)

        var hint = unsafe swl_test_text_input_listener_record()
        unsafe swl_test_text_input_listener_emit_preedit_hint(
            data,
            textInput,
            1,
            3,
            777,
            &hint
        )
        #expect(unsafe hint.kind == SWL_TEST_TEXT_INPUT_LISTENER_PREEDIT_HINT)
        #expect(unsafe hint.start == 1)
        #expect(unsafe hint.end == 3)
        #expect(unsafe hint.hint == 777)
    }

#endif
