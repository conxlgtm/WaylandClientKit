#if SWL_ENABLE_TESTING
    import CWaylandProtocols
    import Testing

    @Suite(.serialized)
    struct PointerCaptureShimContractTests {
        @Test
        func relativePointerRequestPreservesManagerAndPointer() throws {
            let manager = try unsafe #require(OpaquePointer(bitPattern: 0xB101))
            let pointer = try unsafe #require(OpaquePointer(bitPattern: 0xB102))

            ShimRequestRecordingLock.pointerCapture.withLock { _ in
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                let relativePointer = getRelativePointer(manager, pointer)
                let record = unsafe swl_test_pointer_capture_request_record()

                #expect(unsafe relativePointer != nil)
                #expect(unsafe record.call_count == 1)
                #expect(unsafe record.kind == SWL_TEST_POINTER_CAPTURE_GET_RELATIVE_POINTER)
                #expect(unsafe record.object == UnsafeMutableRawPointer(manager))
                #expect(unsafe record.pointer == UnsafeMutableRawPointer(pointer))
            }
        }

        @Test
        func pointerConstraintRequestsPreserveSurfacePointerRegionAndLifetime() throws {
            let constraints = try unsafe #require(OpaquePointer(bitPattern: 0xB201))
            let surface = try unsafe #require(OpaquePointer(bitPattern: 0xB202))
            let pointer = try unsafe #require(OpaquePointer(bitPattern: 0xB203))
            let region = try unsafe #require(OpaquePointer(bitPattern: 0xB204))

            ShimRequestRecordingLock.pointerCapture.withLock { _ in
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                let lockedPointer = unsafe swl_zwp_pointer_constraints_v1_lock_pointer(
                    constraints,
                    surface,
                    pointer,
                    region,
                    1
                )
                let lockRecord = unsafe swl_test_pointer_capture_request_record()
                #expect(unsafe lockedPointer != nil)
                #expect(unsafe lockRecord.call_count == 1)
                #expect(unsafe lockRecord.kind == SWL_TEST_POINTER_CAPTURE_LOCK_POINTER)
                #expect(unsafe lockRecord.object == UnsafeMutableRawPointer(constraints))
                #expect(unsafe lockRecord.surface == UnsafeMutableRawPointer(surface))
                #expect(unsafe lockRecord.pointer == UnsafeMutableRawPointer(pointer))
                #expect(unsafe lockRecord.region == UnsafeMutableRawPointer(region))
                #expect(unsafe lockRecord.lifetime == 1)

                let confinedPointer = confinePointer(constraints, surface, pointer, region, 2)
                let confineRecord = unsafe swl_test_pointer_capture_request_record()
                #expect(unsafe confinedPointer != nil)
                #expect(unsafe confineRecord.call_count == 2)
                #expect(unsafe confineRecord.kind == SWL_TEST_POINTER_CAPTURE_CONFINE_POINTER)
                #expect(unsafe confineRecord.object == UnsafeMutableRawPointer(constraints))
                #expect(unsafe confineRecord.surface == UnsafeMutableRawPointer(surface))
                #expect(unsafe confineRecord.pointer == UnsafeMutableRawPointer(pointer))
                #expect(unsafe confineRecord.region == UnsafeMutableRawPointer(region))
                #expect(unsafe confineRecord.lifetime == 2)
            }
        }

        @Test
        func pointerConstraintStateRequestsPreserveTargetsAndValues() throws {
            let lockedPointer = try unsafe #require(OpaquePointer(bitPattern: 0xB301))
            let confinedPointer = try unsafe #require(OpaquePointer(bitPattern: 0xB302))
            let region = try unsafe #require(OpaquePointer(bitPattern: 0xB303))

            // swiftlint:disable:next closure_body_length
            ShimRequestRecordingLock.pointerCapture.withLock { _ in
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                unsafe swl_zwp_locked_pointer_v1_set_cursor_position_hint(
                    lockedPointer,
                    384,
                    -128
                )
                let hintRecord = unsafe swl_test_pointer_capture_request_record()
                #expect(unsafe hintRecord.call_count == 1)
                #expect(unsafe hintRecord.kind == SWL_TEST_POINTER_CAPTURE_LOCK_SET_CURSOR_HINT)
                #expect(unsafe hintRecord.object == UnsafeMutableRawPointer(lockedPointer))
                #expect(unsafe hintRecord.x == 384)
                #expect(unsafe hintRecord.y == -128)

                unsafe swl_zwp_locked_pointer_v1_set_region(lockedPointer, region)
                let lockRegionRecord = unsafe swl_test_pointer_capture_request_record()
                #expect(unsafe lockRegionRecord.call_count == 2)
                #expect(unsafe lockRegionRecord.kind == SWL_TEST_POINTER_CAPTURE_LOCK_SET_REGION)
                #expect(unsafe lockRegionRecord.object == UnsafeMutableRawPointer(lockedPointer))
                #expect(unsafe lockRegionRecord.region == UnsafeMutableRawPointer(region))

                unsafe swl_zwp_confined_pointer_v1_set_region(confinedPointer, region)
                let confineRegionRecord = unsafe swl_test_pointer_capture_request_record()
                let confineRegionKind = unsafe confineRegionRecord.kind
                let confineRegionObject = unsafe confineRegionRecord.object
                let confinedPointerObject = unsafe UnsafeMutableRawPointer(confinedPointer)
                #expect(unsafe confineRegionRecord.call_count == 3)
                #expect(confineRegionKind == SWL_TEST_POINTER_CAPTURE_CONFINE_SET_REGION)
                #expect(unsafe confineRegionObject == confinedPointerObject)
                #expect(unsafe confineRegionRecord.region == UnsafeMutableRawPointer(region))

                unsafe swl_region_add(region, 1, 2, 3, 4)
                let regionAddRecord = unsafe swl_test_pointer_capture_request_record()
                #expect(unsafe regionAddRecord.call_count == 4)
                #expect(unsafe regionAddRecord.kind == SWL_TEST_POINTER_CAPTURE_REGION_ADD)
                #expect(unsafe regionAddRecord.object == UnsafeMutableRawPointer(region))
                #expect(unsafe regionAddRecord.x == 1)
                #expect(unsafe regionAddRecord.y == 2)
                #expect(unsafe regionAddRecord.width == 3)
                #expect(unsafe regionAddRecord.height == 4)
            }
        }

        @Test
        func relativePointerMotionListenerForwardsTimestampAndDeltas() throws {
            let data = unsafe UnsafeMutableRawPointer(bitPattern: 0xB401)
            let relativePointer = try unsafe #require(OpaquePointer(bitPattern: 0xB402))
            var record = unsafe swl_test_pointer_capture_listener_record()

            unsafe swl_test_relative_pointer_listener_emit_relative_motion(
                data,
                relativePointer,
                1,
                2,
                3,
                -4,
                5,
                -6,
                &record
            )

            #expect(unsafe record.call_count == 1)
            #expect(unsafe record.kind == SWL_TEST_POINTER_CAPTURE_LISTENER_RELATIVE_MOTION)
            #expect(unsafe record.data == data)
            #expect(unsafe record.object == UnsafeMutableRawPointer(relativePointer))
            #expect(unsafe record.utime_hi == 1)
            #expect(unsafe record.utime_lo == 2)
            #expect(unsafe record.dx == 3)
            #expect(unsafe record.dy == -4)
            #expect(unsafe record.dx_unaccel == 5)
            #expect(unsafe record.dy_unaccel == -6)
        }

        @Test
        func pointerConstraintListenersForwardTargets() throws {
            let data = unsafe UnsafeMutableRawPointer(bitPattern: 0xB501)
            let lockedPointer = try unsafe #require(OpaquePointer(bitPattern: 0xB502))
            let confinedPointer = try unsafe #require(OpaquePointer(bitPattern: 0xB503))

            var record = unsafe swl_test_pointer_capture_listener_record()
            unsafe swl_test_locked_pointer_listener_emit_locked(data, lockedPointer, &record)
            #expect(unsafe record.kind == SWL_TEST_POINTER_CAPTURE_LISTENER_LOCKED)
            #expect(unsafe record.data == data)
            #expect(unsafe record.object == UnsafeMutableRawPointer(lockedPointer))

            unsafe swl_test_locked_pointer_listener_emit_unlocked(data, lockedPointer, &record)
            #expect(unsafe record.kind == SWL_TEST_POINTER_CAPTURE_LISTENER_UNLOCKED)
            #expect(unsafe record.object == UnsafeMutableRawPointer(lockedPointer))

            unsafe swl_test_confined_pointer_listener_emit_confined(data, confinedPointer, &record)
            #expect(unsafe record.kind == SWL_TEST_POINTER_CAPTURE_LISTENER_CONFINED)
            #expect(unsafe record.object == UnsafeMutableRawPointer(confinedPointer))

            unsafe swl_test_confined_pointer_listener_emit_unconfined(
                data,
                confinedPointer,
                &record
            )
            #expect(unsafe record.kind == SWL_TEST_POINTER_CAPTURE_LISTENER_UNCONFINED)
            #expect(unsafe record.object == UnsafeMutableRawPointer(confinedPointer))
        }

        @Test
        func pointerCaptureDestroyWrappersUseMatchingTargets() throws {
            let relativeManager = try unsafe #require(OpaquePointer(bitPattern: 0xB601))
            let relativePointer = try unsafe #require(OpaquePointer(bitPattern: 0xB602))
            let constraints = try unsafe #require(OpaquePointer(bitPattern: 0xB603))
            let lockedPointer = try unsafe #require(OpaquePointer(bitPattern: 0xB604))
            let confinedPointer = try unsafe #require(OpaquePointer(bitPattern: 0xB605))
            let region = try unsafe #require(OpaquePointer(bitPattern: 0xB606))

            // swiftlint:disable:next closure_body_length
            ShimRequestRecordingLock.pointerCapture.withLock { _ in
                swl_test_pointer_capture_request_recording_begin()
                defer { swl_test_pointer_capture_request_recording_end() }

                unsafe swl_zwp_relative_pointer_manager_v1_destroy(relativeManager)
                assertDestroy(
                    expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_RELATIVE_MANAGER,
                    object: relativeManager
                )

                unsafe swl_zwp_relative_pointer_v1_destroy(relativePointer)
                assertDestroy(
                    expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_RELATIVE_POINTER,
                    object: relativePointer
                )

                unsafe swl_zwp_pointer_constraints_v1_destroy(constraints)
                assertDestroy(
                    expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_CONSTRAINTS,
                    object: constraints
                )

                unsafe swl_zwp_locked_pointer_v1_destroy(lockedPointer)
                assertDestroy(
                    expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_LOCKED_POINTER,
                    object: lockedPointer
                )

                unsafe swl_zwp_confined_pointer_v1_destroy(confinedPointer)
                assertDestroy(
                    expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_CONFINED_POINTER,
                    object: confinedPointer
                )

                unsafe swl_region_destroy(region)
                assertDestroy(
                    expectedKind: SWL_TEST_POINTER_CAPTURE_DESTROY_REGION,
                    object: region
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

        @safe
        private func getRelativePointer(
            _ manager: OpaquePointer?,
            _ pointer: OpaquePointer?
        ) -> OpaquePointer? {
            unsafe swl_zwp_relative_pointer_manager_v1_get_relative_pointer(manager, pointer)
        }

        @safe
        private func confinePointer(
            _ constraints: OpaquePointer?,
            _ surface: OpaquePointer?,
            _ pointer: OpaquePointer?,
            _ region: OpaquePointer?,
            _ lifetime: UInt32
        ) -> OpaquePointer? {
            unsafe swl_zwp_pointer_constraints_v1_confine_pointer(
                constraints,
                surface,
                pointer,
                region,
                lifetime
            )
        }
    }

#endif
