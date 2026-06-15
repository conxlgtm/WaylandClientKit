#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing

    @Suite(.serialized)
    struct PointerGestureShortcutShimContractTests {
        @Test
        func pointerGestureRequestsPreserveManagerAndPointer() throws {
            let gestures = try unsafe #require(OpaquePointer(bitPattern: 0xB111))
            let pointer = try unsafe #require(OpaquePointer(bitPattern: 0xB112))

            assertGestureRequest(
                gestures: gestures,
                pointer: pointer,
                expectedKind: SWL_TEST_POINTER_CAPTURE_GET_SWIPE_GESTURE,
                request: unsafe swl_zwp_pointer_gestures_v1_get_swipe_gesture
            )
            assertGestureRequest(
                gestures: gestures,
                pointer: pointer,
                expectedKind: SWL_TEST_POINTER_CAPTURE_GET_PINCH_GESTURE,
                request: unsafe swl_zwp_pointer_gestures_v1_get_pinch_gesture
            )
            assertGestureRequest(
                gestures: gestures,
                pointer: pointer,
                expectedKind: SWL_TEST_POINTER_CAPTURE_GET_HOLD_GESTURE,
                request: unsafe swl_zwp_pointer_gestures_v1_get_hold_gesture
            )
        }

        @Test
        func keyboardShortcutsInhibitRequestPreservesManagerSurfaceAndSeat() throws {
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xB121))
            let surface = try unsafe #require(OpaquePointer(bitPattern: 0xB122))
            let seat = try unsafe #require(OpaquePointer(bitPattern: 0xB123))

            ShimRequestRecordingLock.pointerCapture.withLock { _ in
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                let inhibitor =
                    unsafe swl_zwp_keyboard_shortcuts_inhibit_manager_v1_inhibit_shortcuts(
                        manager,
                        surface,
                        seat
                    )
                let record = unsafe swl_test_pointer_capture_request_record()
                #expect(unsafe inhibitor != nil)
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_POINTER_CAPTURE_INHIBIT_SHORTCUTS)
                #expect(unsafe record.object == UnsafeMutableRawPointer(manager))
                #expect(unsafe record.surface == UnsafeMutableRawPointer(surface))
                #expect(unsafe record.seat == UnsafeMutableRawPointer(seat))
            }
        }

        @Test
        func keyboardShortcutsInhibitorListenerForwardsActiveAndInactive() throws {
            let data = unsafe UnsafeMutableRawPointer(bitPattern: 0xB131)
            let inhibitor = try unsafe #require(OpaquePointer(bitPattern: 0xB132))
            var activeRecord = unsafe swl_test_pointer_capture_listener_record()
            var inactiveRecord = unsafe swl_test_pointer_capture_listener_record()

            unsafe swl_test_keyboard_shortcuts_inhibitor_listener_emit_active(
                data,
                inhibitor,
                &activeRecord
            )
            unsafe swl_test_keyboard_shortcuts_inhibitor_listener_emit_inactive(
                data,
                inhibitor,
                &inactiveRecord
            )

            #expect(unsafe activeRecord.call_count == 1)
            #expect(
                unsafe activeRecord.kind
                    == SWL_TEST_POINTER_CAPTURE_LISTENER_SHORTCUTS_ACTIVE
            )
            #expect(unsafe activeRecord.data == data)
            #expect(unsafe activeRecord.object == UnsafeMutableRawPointer(inhibitor))
            #expect(unsafe inactiveRecord.call_count == 1)
            #expect(
                unsafe inactiveRecord.kind
                    == SWL_TEST_POINTER_CAPTURE_LISTENER_SHORTCUTS_INACTIVE
            )
            #expect(unsafe inactiveRecord.data == data)
            #expect(unsafe inactiveRecord.object == UnsafeMutableRawPointer(inhibitor))
        }

        @Test
        func gestureAndShortcutDestroyWrappersUseMatchingTargets() throws {
            let gestures = try unsafe #require(OpaquePointer(bitPattern: 0xB607))
            let swipe = try unsafe #require(OpaquePointer(bitPattern: 0xB608))
            let pinch = try unsafe #require(OpaquePointer(bitPattern: 0xB609))
            let hold = try unsafe #require(OpaquePointer(bitPattern: 0xB60A))
            let shortcutsManager = try unsafe #require(OpaquePointer(bitPattern: 0xB60B))
            let shortcutsInhibitor = try unsafe #require(OpaquePointer(bitPattern: 0xB60C))

            assertDestroyRequest(
                object: gestures,
                expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_GESTURES,
                destroy: unsafe swl_zwp_pointer_gestures_v1_destroy
            )
            assertDestroyRequest(
                object: gestures,
                expectedKind: SWL_TEST_POINTER_CAPTURE_RELEASE_GESTURES,
                destroy: unsafe swl_zwp_pointer_gestures_v1_release
            )
            assertDestroyRequest(
                object: swipe,
                expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_SWIPE_GESTURE,
                destroy: unsafe swl_zwp_pointer_gesture_swipe_v1_destroy
            )
            assertDestroyRequest(
                object: pinch,
                expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_PINCH_GESTURE,
                destroy: unsafe swl_zwp_pointer_gesture_pinch_v1_destroy
            )
            assertDestroyRequest(
                object: hold,
                expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_HOLD_GESTURE,
                destroy: unsafe swl_zwp_pointer_gesture_hold_v1_destroy
            )
            assertDestroyRequest(
                object: shortcutsManager,
                expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_SHORTCUTS_MANAGER,
                destroy: unsafe swl_zwp_keyboard_shortcuts_inhibit_manager_v1_destroy
            )
            assertDestroyRequest(
                object: shortcutsInhibitor,
                expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_SHORTCUTS_INHIBITOR,
                destroy: unsafe swl_zwp_keyboard_shortcuts_inhibitor_v1_destroy
            )
        }

        @safe
        private func assertGestureRequest(
            gestures: OpaquePointer,
            pointer: OpaquePointer,
            expectedKind: swl_test_pointer_capture_request_kind,
            request: (OpaquePointer?, OpaquePointer?) -> OpaquePointer?
        ) {
            ShimRequestRecordingLock.pointerCapture.withLock { _ in
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                let gesture = unsafe request(gestures, pointer)
                let record = unsafe swl_test_pointer_capture_request_record()
                #expect(unsafe gesture != nil)
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == expectedKind)
                #expect(unsafe record.object == UnsafeMutableRawPointer(gestures))
                #expect(unsafe record.pointer == UnsafeMutableRawPointer(pointer))
            }
        }

        @safe
        private func assertDestroyRequest(
            object rawObject: OpaquePointer,
            expectedKind: swl_test_pointer_capture_destroy_kind,
            destroy: (OpaquePointer?) -> Void,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            ShimRequestRecordingLock.pointerCapture.withLock { _ in
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }
                unsafe destroy(rawObject)
                assertDestroy(
                    expectedKind: expectedKind,
                    object: rawObject,
                    sourceLocation: sourceLocation
                )
            }
        }

        @safe
        private func assertDestroy(
            expectedKind: swl_test_pointer_capture_destroy_kind,
            object rawObject: OpaquePointer,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            let object = unsafe UnsafeMutableRawPointer(rawObject)
            let record = unsafe swl_test_pointer_capture_destroy_record()
            #expect(unsafe record.kind == expectedKind, sourceLocation: sourceLocation)
            #expect(unsafe record.object == object)
        }
    }
#endif
