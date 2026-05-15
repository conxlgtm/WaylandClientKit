import CEGLShims
import Testing

@Suite
struct EGLShimTests {
    @Test
    func nullEGLInputsFailWithoutDereference() {
        let displayIsNil = unsafe swl_egl_display_for_gbm_device(nil) == nil
        var major: Int32 = 0
        var minor: Int32 = 0
        let initializeResult = unsafe swl_egl_initialize(nil, &major, &minor)
        let extensionsAreNil = unsafe swl_egl_query_display_extensions(nil) == nil
        let configIsNil = unsafe swl_egl_choose_gles_window_config(nil, 0) == nil
        let contextIsNil = unsafe swl_egl_create_gles2_context(nil, nil) == nil
        let surfaceIsNil = unsafe swl_egl_create_window_surface(nil, nil, nil) == nil
        let makeCurrentResult = swl_egl_make_current(nil, nil, nil)
        let clearCurrentResult = swl_egl_clear_current(nil)
        let swapResult = swl_egl_swap_buffers(nil, nil)
        let clearResult = swl_gles2_clear_rgba(0, 1, 0, 0, 0, 1)
        let readResult = swl_gles2_read_center_pixel_rgba8(1, 1, nil)

        #expect(displayIsNil)
        #expect(initializeResult == -1)
        #expect(major == 0)
        #expect(minor == 0)
        #expect(extensionsAreNil)
        #expect(configIsNil)
        #expect(contextIsNil)
        #expect(surfaceIsNil)
        #expect(makeCurrentResult == -1)
        #expect(clearCurrentResult == -1)
        #expect(swapResult == -1)
        #expect(clearResult == -1)
        #expect(readResult == -1)

        swl_egl_destroy_context(nil, nil)
        swl_egl_destroy_surface(nil, nil)
        swl_egl_terminate(nil)
    }

    @Test
    func clientExtensionsQueryIsCallable() {
        _ = unsafe swl_egl_query_client_extensions()
        _ = swl_egl_error()
        _ = swl_gles2_error()
    }
}
