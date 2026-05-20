#if SWL_ENABLE_TESTING
    import CGBMShims
    import Testing

    @Suite(.serialized)
    struct GBMShimTests {
        @Test
        func drmFormatConstantsAreAvailable() {
            #expect(swl_drm_format_xrgb8888() == 875_713_112)
            #expect(swl_drm_format_argb8888() == 875_713_089)
            #expect(swl_drm_format_mod_linear() == 0)
            #expect(swl_drm_format_mod_invalid() == 72_057_594_037_927_935)
        }

        @Test
        func gbmUseFlagsAreAvailable() {
            #expect(swl_gbm_bo_use_scanout() == 1)
            #expect(swl_gbm_bo_use_rendering() == 4)
            #expect(swl_gbm_bo_use_write() == 8)
            #expect(swl_gbm_bo_use_linear() == 16)
        }

        @Test
        func nullGBMDeviceAndBufferInputsFailWithoutDereference() {
            let createDeviceIsNil = unsafe swl_gbm_create_device(-1) == nil
            let backendNameIsNil = unsafe swl_gbm_device_get_backend_name(nil) == nil
            let formatSupported = swl_gbm_device_is_format_supported(nil, 0, 0)
            let modifierPlaneCount = swl_gbm_device_get_format_modifier_plane_count(nil, 0, 0)
            let bufferIsNil =
                unsafe swl_gbm_bo_create(nil, 1, 1, swl_drm_format_xrgb8888(), 0) == nil
            let bufferWithModifiersIsNil =
                unsafe swl_gbm_bo_create_with_modifiers2(
                    nil,
                    1,
                    1,
                    swl_drm_format_xrgb8888(),
                    nil,
                    0,
                    0
                ) == nil
            let bufferWithModifierIsNil =
                unsafe swl_gbm_bo_create_with_modifier2(
                    nil,
                    1,
                    1,
                    swl_drm_format_xrgb8888(),
                    swl_drm_format_mod_linear(),
                    0
                ) == nil
            let bufferForModifierIsNil =
                unsafe swl_gbm_bo_create_for_modifier(
                    nil,
                    1,
                    1,
                    swl_drm_format_xrgb8888(),
                    swl_drm_format_mod_invalid(),
                    0
                ) == nil

            #expect(createDeviceIsNil)
            #expect(backendNameIsNil)
            #expect(formatSupported == 0)
            #expect(modifierPlaneCount == -1)
            #expect(bufferIsNil)
            #expect(bufferWithModifiersIsNil)
            #expect(bufferWithModifierIsNil)
            #expect(bufferForModifierIsNil)

            var exportedBuffer = swl_gbm_bo_export()
            let exportResult = unsafe swl_gbm_bo_export_dmabuf(nil, &exportedBuffer)
            let missingPlaneTakenFD =
                unsafe swl_gbm_bo_export_take_plane_fd(&exportedBuffer, 0)
            let missingPlaneOffset =
                unsafe swl_gbm_bo_export_plane_offset(&exportedBuffer, 0)
            let missingPlaneStride =
                unsafe swl_gbm_bo_export_plane_stride(&exportedBuffer, 0)
            #expect(exportedBuffer.plane_count == 0)
            #expect(exportResult == -1)
            #expect(missingPlaneTakenFD == -1)
            #expect(missingPlaneOffset == 0)
            #expect(missingPlaneStride == 0)

            swl_gbm_bo_destroy(nil)
            swl_gbm_device_destroy(nil)
            swl_gbm_bo_export_close(nil)
        }

        @Test
        func nullGBMSurfaceInputsFailWithoutDereference() {
            let surfaceIsNil =
                unsafe swl_gbm_surface_create_for_modifier(
                    nil,
                    1,
                    1,
                    swl_drm_format_xrgb8888(),
                    swl_drm_format_mod_invalid(),
                    swl_gbm_bo_use_rendering()
                ) == nil
            let lockedBufferIsNil = unsafe swl_gbm_surface_lock_front_buffer(nil) == nil
            #expect(surfaceIsNil)
            #expect(lockedBufferIsNil)

            swl_gbm_surface_release_buffer(nil, nil)
            swl_gbm_surface_destroy(nil)
        }

        @Test
        func invalidModifierAllocationUsesImplicitGBMCreate() throws {
            let device = try unsafe #require(OpaquePointer(bitPattern: 0x6006))

            swl_test_gbm_bo_create_recording_begin()
            defer { swl_test_gbm_bo_create_recording_end() }

            let buffer = unsafe swl_gbm_bo_create_for_modifier(
                device,
                64,
                32,
                swl_drm_format_xrgb8888(),
                swl_drm_format_mod_invalid(),
                swl_gbm_bo_use_rendering() | swl_gbm_bo_use_linear()
            )

            let record = unsafe swl_test_gbm_bo_create_record()
            #expect(unsafe buffer == nil)
            #expect(unsafe record.call_count == 1)
            #expect(unsafe record.kind == SWL_TEST_GBM_BO_CREATE)
            #expect(unsafe record.device == UnsafeMutableRawPointer(device))
            #expect(unsafe record.width == 64)
            #expect(unsafe record.height == 32)
            #expect(unsafe record.format == swl_drm_format_xrgb8888())
            #expect(unsafe record.modifier == swl_drm_format_mod_invalid())
            #expect(unsafe record.modifier_count == 0)
            #expect(unsafe record.flags == swl_gbm_bo_use_rendering() | swl_gbm_bo_use_linear())
        }

        @Test
        func explicitModifierAllocationUsesModifierGBMCreate() throws {
            let device = try unsafe #require(OpaquePointer(bitPattern: 0x7007))

            swl_test_gbm_bo_create_recording_begin()
            defer { swl_test_gbm_bo_create_recording_end() }

            let buffer = unsafe swl_gbm_bo_create_for_modifier(
                device,
                128,
                64,
                swl_drm_format_argb8888(),
                swl_drm_format_mod_linear(),
                swl_gbm_bo_use_scanout()
            )

            let record = unsafe swl_test_gbm_bo_create_record()
            #expect(unsafe buffer == nil)
            #expect(unsafe record.call_count == 1)
            #expect(unsafe record.kind == SWL_TEST_GBM_BO_CREATE_WITH_MODIFIERS2)
            #expect(unsafe record.device == UnsafeMutableRawPointer(device))
            #expect(unsafe record.width == 128)
            #expect(unsafe record.height == 64)
            #expect(unsafe record.format == swl_drm_format_argb8888())
            #expect(unsafe record.modifier == swl_drm_format_mod_linear())
            #expect(unsafe record.modifier_count == 1)
            #expect(unsafe record.flags == swl_gbm_bo_use_scanout())
        }

        @Test
        func explicitModifierAllocationDropsLinearUseFlag() throws {
            let device = try unsafe #require(OpaquePointer(bitPattern: 0x8008))

            swl_test_gbm_bo_create_recording_begin()
            defer { swl_test_gbm_bo_create_recording_end() }

            let buffer = unsafe swl_gbm_bo_create_for_modifier(
                device,
                256,
                128,
                swl_drm_format_argb8888(),
                swl_drm_format_mod_linear(),
                swl_gbm_bo_use_scanout() | swl_gbm_bo_use_linear()
            )

            let record = unsafe swl_test_gbm_bo_create_record()
            #expect(unsafe buffer == nil)
            #expect(unsafe record.call_count == 1)
            #expect(unsafe record.kind == SWL_TEST_GBM_BO_CREATE_WITH_MODIFIERS2)
            #expect(unsafe record.modifier == swl_drm_format_mod_linear())
            #expect(unsafe record.modifier_count == 1)
            #expect(unsafe record.flags == swl_gbm_bo_use_scanout())
        }
    }

#endif
