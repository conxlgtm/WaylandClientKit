#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing

    @Suite(.serialized)
    struct ActivationShimContractTests {
        @Test
        func activationTokenRequestsPreserveSerialSeatAppIDSurfaceAndCommit() throws {
            let token = try unsafe #require(OpaquePointer(bitPattern: 0xA101))
            let seat = try unsafe #require(OpaquePointer(bitPattern: 0xA102))
            let surface = try unsafe #require(OpaquePointer(bitPattern: 0xA103))

            ShimRequestRecordingLock.activation.withLock { _ in
                swl_test_activation_request_recording_begin()
                defer { swl_test_activation_request_recording_end() }

                unsafe swl_xdg_activation_token_v1_set_serial(token, 77, seat)
                let serialRecord = unsafe swl_test_activation_request_record()
                #expect(unsafe serialRecord.call_count == 1)
                #expect(unsafe serialRecord.kind == SWL_TEST_ACTIVATION_TOKEN_SET_SERIAL)
                #expect(unsafe serialRecord.object == UnsafeMutableRawPointer(token))
                #expect(unsafe serialRecord.seat == UnsafeMutableRawPointer(seat))
                #expect(unsafe serialRecord.serial == 77)

                unsafe "org.swiftwayland.Test".withCString { appID in
                    unsafe swl_xdg_activation_token_v1_set_app_id(token, appID)
                }
                let appIDRecord = unsafe swl_test_activation_request_record()
                let appIDText = unsafe appIDRecord.text.map { unsafe String(cString: $0) }
                #expect(unsafe appIDRecord.call_count == 2)
                #expect(unsafe appIDRecord.kind == SWL_TEST_ACTIVATION_TOKEN_SET_APP_ID)
                #expect(appIDText == "org.swiftwayland.Test")

                unsafe swl_xdg_activation_token_v1_set_surface(token, surface)
                let surfaceRecord = unsafe swl_test_activation_request_record()
                #expect(unsafe surfaceRecord.call_count == 3)
                #expect(unsafe surfaceRecord.kind == SWL_TEST_ACTIVATION_TOKEN_SET_SURFACE)
                #expect(unsafe surfaceRecord.surface == UnsafeMutableRawPointer(surface))

                unsafe swl_xdg_activation_token_v1_commit(token)
                let commitRecord = unsafe swl_test_activation_request_record()
                #expect(unsafe commitRecord.call_count == 4)
                #expect(unsafe commitRecord.kind == SWL_TEST_ACTIVATION_TOKEN_COMMIT)
                #expect(unsafe commitRecord.object == UnsafeMutableRawPointer(token))
            }
        }

        @Test
        func activationManagerRequestsAndActivatePreserveTargets() throws {
            let activation = try unsafe #require(OpaquePointer(bitPattern: 0xA201))
            let surface = try unsafe #require(OpaquePointer(bitPattern: 0xA202))

            ShimRequestRecordingLock.activation.withLock { _ in
                swl_test_activation_request_recording_begin()
                defer { swl_test_activation_request_recording_end() }

                let token = unsafe swl_xdg_activation_v1_get_activation_token(activation)
                #expect(unsafe token != nil)
                let tokenRecord = unsafe swl_test_activation_request_record()
                #expect(unsafe tokenRecord.call_count == 1)
                #expect(unsafe tokenRecord.kind == SWL_TEST_ACTIVATION_GET_TOKEN)
                #expect(unsafe tokenRecord.object == UnsafeMutableRawPointer(activation))

                unsafe "opaque-token".withCString { tokenValue in
                    unsafe swl_xdg_activation_v1_activate(activation, tokenValue, surface)
                }
                let activateRecord = unsafe swl_test_activation_request_record()
                let activateText = unsafe activateRecord.text.map { unsafe String(cString: $0) }
                #expect(unsafe activateRecord.call_count == 2)
                #expect(unsafe activateRecord.kind == SWL_TEST_ACTIVATION_ACTIVATE)
                #expect(unsafe activateRecord.object == UnsafeMutableRawPointer(activation))
                #expect(unsafe activateRecord.surface == UnsafeMutableRawPointer(surface))
                #expect(activateText == "opaque-token")
            }
        }

        @Test
        func activationDoneListenerForwardsTokenValue() throws {
            let data = unsafe UnsafeMutableRawPointer(bitPattern: 0xA301)
            let token = try unsafe #require(OpaquePointer(bitPattern: 0xA302))
            var record = unsafe swl_test_activation_listener_record()

            unsafe "done-token".withCString { tokenValue in
                unsafe swl_test_activation_listener_emit_done(
                    data,
                    token,
                    tokenValue,
                    &record
                )
                let recordedText = unsafe record.text.map { unsafe String(cString: $0) }
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_ACTIVATION_LISTENER_DONE)
                #expect(unsafe record.data == data)
                #expect(unsafe record.token == UnsafeMutableRawPointer(token))
                #expect(recordedText == "done-token")
            }
        }

        @Test
        func activationDestroyWrappersUseMatchingTargets() throws {
            let activation = try unsafe #require(OpaquePointer(bitPattern: 0xA401))
            let token = try unsafe #require(OpaquePointer(bitPattern: 0xA402))

            ShimRequestRecordingLock.activation.withLock { _ in
                swl_test_activation_request_recording_begin()
                defer { swl_test_activation_request_recording_end() }

                unsafe swl_xdg_activation_v1_destroy(activation)
                let activationRecord = unsafe swl_test_activation_destroy_record()
                #expect(unsafe activationRecord.call_count == 1)
                #expect(unsafe activationRecord.kind == SWL_TEST_ACTIVATION_DESTROY_MANAGER)
                #expect(unsafe activationRecord.object == UnsafeMutableRawPointer(activation))

                unsafe swl_xdg_activation_token_v1_destroy(token)
                let tokenRecord = unsafe swl_test_activation_destroy_record()
                #expect(unsafe tokenRecord.call_count == 2)
                #expect(unsafe tokenRecord.kind == SWL_TEST_ACTIVATION_DESTROY_TOKEN)
                #expect(unsafe tokenRecord.object == UnsafeMutableRawPointer(token))
            }
        }
    }

#endif
