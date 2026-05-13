import CGBMShims
import Testing

@Suite
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
    func nullGBMInputsFailWithoutDereference() {
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

        #expect(createDeviceIsNil)
        #expect(backendNameIsNil)
        #expect(formatSupported == 0)
        #expect(modifierPlaneCount == -1)
        #expect(bufferIsNil)
        #expect(bufferWithModifiersIsNil)

        var exportedBuffer = swl_gbm_bo_export()
        let exportResult = unsafe swl_gbm_bo_export_dmabuf(nil, &exportedBuffer)
        #expect(exportedBuffer.plane_count == 0)
        #expect(exportResult == -1)

        swl_gbm_bo_destroy(nil)
        swl_gbm_device_destroy(nil)
        swl_gbm_bo_export_close(nil)
    }
}
