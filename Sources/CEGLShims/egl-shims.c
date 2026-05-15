#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <errno.h>
#include <gbm.h>
#include <stdint.h>

#include "swift-wayland-egl-shims.h"

#ifndef EGL_PLATFORM_GBM_KHR
#define EGL_PLATFORM_GBM_KHR 0x31D7
#endif

static EGLDisplay swl_egl_cast_display(swl_egl_display display)
{
    return (EGLDisplay) display;
}

static EGLConfig swl_egl_cast_config(swl_egl_config config)
{
    return (EGLConfig) config;
}

static EGLContext swl_egl_cast_context(swl_egl_context context)
{
    return (EGLContext) context;
}

static EGLSurface swl_egl_cast_surface(swl_egl_surface surface)
{
    return (EGLSurface) surface;
}

#ifdef SWL_ENABLE_TESTING
static int32_t swl_egl_error_default(void);
static int32_t swl_egl_make_current_default(
    swl_egl_display display,
    swl_egl_surface surface,
    swl_egl_context context);
static int32_t swl_egl_clear_current_default(swl_egl_display display);
static int32_t swl_egl_swap_buffers_default(
    swl_egl_display display,
    swl_egl_surface surface);
static int32_t swl_gles2_clear_rgba_default(
    uint32_t width,
    uint32_t height,
    float red,
    float green,
    float blue,
    float alpha);
static int32_t swl_gles2_read_center_pixel_rgba8_default(
    uint32_t width,
    uint32_t height,
    uint8_t *out_rgba);

static struct swl_test_egl_draw_record swl_test_egl_draw_latest;
static int32_t swl_test_egl_clear_current_result;
static int32_t swl_test_egl_error_value;

static int32_t (*swl_egl_error_impl)(void) = swl_egl_error_default;
static int32_t (*swl_egl_make_current_impl)(
    swl_egl_display display,
    swl_egl_surface surface,
    swl_egl_context context) = swl_egl_make_current_default;
static int32_t (*swl_egl_clear_current_impl)(
    swl_egl_display display) = swl_egl_clear_current_default;
static int32_t (*swl_egl_swap_buffers_impl)(
    swl_egl_display display,
    swl_egl_surface surface) = swl_egl_swap_buffers_default;
static int32_t (*swl_gles2_clear_rgba_impl)(
    uint32_t width,
    uint32_t height,
    float red,
    float green,
    float blue,
    float alpha) = swl_gles2_clear_rgba_default;
static int32_t (*swl_gles2_read_center_pixel_rgba8_impl)(
    uint32_t width,
    uint32_t height,
    uint8_t *out_rgba) = swl_gles2_read_center_pixel_rgba8_default;

static int32_t swl_test_egl_error_record(void)
{
    return swl_test_egl_error_value;
}

static int32_t swl_test_egl_make_current_record(
    swl_egl_display display,
    swl_egl_surface surface,
    swl_egl_context context)
{
    swl_test_egl_draw_latest.make_current_call_count += 1;
    swl_test_egl_draw_latest.display = display;
    swl_test_egl_draw_latest.surface = surface;
    swl_test_egl_draw_latest.context = context;
    return 0;
}

static int32_t swl_test_egl_clear_current_record(swl_egl_display display)
{
    swl_test_egl_draw_latest.clear_current_call_count += 1;
    swl_test_egl_draw_latest.display = display;
    return swl_test_egl_clear_current_result;
}

static int32_t swl_test_egl_swap_buffers_record(
    swl_egl_display display,
    swl_egl_surface surface)
{
    swl_test_egl_draw_latest.swap_buffers_call_count += 1;
    swl_test_egl_draw_latest.display = display;
    swl_test_egl_draw_latest.surface = surface;
    return 0;
}

static int32_t swl_test_gles2_clear_rgba_record(
    uint32_t width,
    uint32_t height,
    float red,
    float green,
    float blue,
    float alpha)
{
    (void) width;
    (void) height;
    (void) red;
    (void) green;
    (void) blue;
    (void) alpha;
    swl_test_egl_draw_latest.clear_call_count += 1;
    return 0;
}

static int32_t swl_test_gles2_read_center_pixel_rgba8_record(
    uint32_t width,
    uint32_t height,
    uint8_t *out_rgba)
{
    (void) width;
    (void) height;
    swl_test_egl_draw_latest.read_pixel_call_count += 1;
    if (out_rgba != NULL)
    {
        out_rgba[0] = 255;
        out_rgba[1] = 0;
        out_rgba[2] = 0;
        out_rgba[3] = 255;
    }
    return 0;
}
#else
#define swl_egl_error_impl swl_egl_error_default
#define swl_egl_make_current_impl swl_egl_make_current_default
#define swl_egl_clear_current_impl swl_egl_clear_current_default
#define swl_egl_swap_buffers_impl swl_egl_swap_buffers_default
#define swl_gles2_clear_rgba_impl swl_gles2_clear_rgba_default
#define swl_gles2_read_center_pixel_rgba8_impl \
    swl_gles2_read_center_pixel_rgba8_default
#endif

const char *swl_egl_query_client_extensions(void)
{
    return eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS);
}

const char *swl_egl_query_display_extensions(swl_egl_display display)
{
    EGLDisplay egl_display = swl_egl_cast_display(display);
    if (egl_display == EGL_NO_DISPLAY)
    {
        errno = EINVAL;
        return NULL;
    }

    return eglQueryString(egl_display, EGL_EXTENSIONS);
}

static int32_t swl_egl_error_default(void)
{
    return (int32_t) eglGetError();
}

int32_t swl_egl_error(void)
{
    return swl_egl_error_impl();
}

uint32_t swl_gles2_error(void)
{
    return (uint32_t) glGetError();
}

swl_egl_display swl_egl_display_for_gbm_device(struct gbm_device *device)
{
    if (device == NULL)
    {
        errno = EINVAL;
        return NULL;
    }

    EGLDisplay display = EGL_NO_DISPLAY;

#ifdef EGL_VERSION_1_5
    display = eglGetPlatformDisplay(EGL_PLATFORM_GBM_KHR, device, NULL);
#endif

    if (display == EGL_NO_DISPLAY)
    {
        PFNEGLGETPLATFORMDISPLAYEXTPROC get_platform_display =
            (PFNEGLGETPLATFORMDISPLAYEXTPROC) eglGetProcAddress(
                "eglGetPlatformDisplayEXT");
        if (get_platform_display != NULL)
        {
            display = get_platform_display(EGL_PLATFORM_GBM_KHR, device, NULL);
        }
    }

    if (display == EGL_NO_DISPLAY)
    {
        display = eglGetDisplay((EGLNativeDisplayType) device);
    }

    if (display == EGL_NO_DISPLAY)
    {
        errno = ENODEV;
        return NULL;
    }

    return (swl_egl_display) display;
}

int32_t swl_egl_initialize(
    swl_egl_display display,
    int32_t *out_major,
    int32_t *out_minor)
{
    EGLDisplay egl_display = swl_egl_cast_display(display);
    if (egl_display == EGL_NO_DISPLAY)
    {
        errno = EINVAL;
        return -1;
    }

    EGLint major = 0;
    EGLint minor = 0;
    if (eglInitialize(egl_display, &major, &minor) != EGL_TRUE)
    {
        return -1;
    }

    if (out_major != NULL)
    {
        *out_major = (int32_t) major;
    }
    if (out_minor != NULL)
    {
        *out_minor = (int32_t) minor;
    }

    return 0;
}

void swl_egl_terminate(swl_egl_display display)
{
    EGLDisplay egl_display = swl_egl_cast_display(display);
    if (egl_display != EGL_NO_DISPLAY)
    {
        eglTerminate(egl_display);
    }
}

int32_t swl_egl_bind_gles_api(void)
{
    return eglBindAPI(EGL_OPENGL_ES_API) == EGL_TRUE ? 0 : -1;
}

swl_egl_config swl_egl_choose_gles_window_config(
    swl_egl_display display,
    uint32_t native_visual_id)
{
    EGLDisplay egl_display = swl_egl_cast_display(display);
    if (egl_display == EGL_NO_DISPLAY)
    {
        errno = EINVAL;
        return NULL;
    }

    const EGLint attributes[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_NONE,
    };
    EGLConfig configs[64] = {NULL};
    EGLint config_count = 0;
    if (eglChooseConfig(egl_display, attributes, configs, 64, &config_count) !=
        EGL_TRUE)
    {
        return NULL;
    }
    if (config_count <= 0)
    {
        errno = ENODEV;
        return NULL;
    }

    for (EGLint index = 0; index < config_count && index < 64; index++)
    {
        EGLint visual_id = 0;
        if (eglGetConfigAttrib(
                egl_display,
                configs[index],
                EGL_NATIVE_VISUAL_ID,
                &visual_id) == EGL_TRUE &&
            (uint32_t) visual_id == native_visual_id)
        {
            return (swl_egl_config) configs[index];
        }
    }

    errno = ENODEV;
    return NULL;
}

swl_egl_context swl_egl_create_gles2_context(
    swl_egl_display display,
    swl_egl_config config)
{
    EGLDisplay egl_display = swl_egl_cast_display(display);
    EGLConfig egl_config = swl_egl_cast_config(config);
    if (egl_display == EGL_NO_DISPLAY || egl_config == NULL)
    {
        errno = EINVAL;
        return NULL;
    }

    const EGLint attributes[] = {
        EGL_CONTEXT_CLIENT_VERSION, 2,
        EGL_NONE,
    };
    EGLContext context = eglCreateContext(
        egl_display,
        egl_config,
        EGL_NO_CONTEXT,
        attributes);
    return context == EGL_NO_CONTEXT ? NULL : (swl_egl_context) context;
}

void swl_egl_destroy_context(
    swl_egl_display display,
    swl_egl_context context)
{
    EGLDisplay egl_display = swl_egl_cast_display(display);
    EGLContext egl_context = swl_egl_cast_context(context);
    if (egl_display != EGL_NO_DISPLAY && egl_context != EGL_NO_CONTEXT)
    {
        eglDestroyContext(egl_display, egl_context);
    }
}

swl_egl_surface swl_egl_create_window_surface(
    swl_egl_display display,
    swl_egl_config config,
    struct gbm_surface *surface)
{
    EGLDisplay egl_display = swl_egl_cast_display(display);
    EGLConfig egl_config = swl_egl_cast_config(config);
    if (egl_display == EGL_NO_DISPLAY || egl_config == NULL || surface == NULL)
    {
        errno = EINVAL;
        return NULL;
    }

    EGLSurface egl_surface = eglCreateWindowSurface(
        egl_display,
        egl_config,
        (EGLNativeWindowType) surface,
        NULL);
    return egl_surface == EGL_NO_SURFACE ? NULL : (swl_egl_surface) egl_surface;
}

void swl_egl_destroy_surface(
    swl_egl_display display,
    swl_egl_surface surface)
{
    EGLDisplay egl_display = swl_egl_cast_display(display);
    EGLSurface egl_surface = swl_egl_cast_surface(surface);
    if (egl_display != EGL_NO_DISPLAY && egl_surface != EGL_NO_SURFACE)
    {
        eglDestroySurface(egl_display, egl_surface);
    }
}

static int32_t swl_egl_make_current_default(
    swl_egl_display display,
    swl_egl_surface surface,
    swl_egl_context context)
{
    EGLDisplay egl_display = swl_egl_cast_display(display);
    EGLSurface egl_surface = swl_egl_cast_surface(surface);
    EGLContext egl_context = swl_egl_cast_context(context);
    if (
        egl_display == EGL_NO_DISPLAY ||
        egl_surface == EGL_NO_SURFACE ||
        egl_context == EGL_NO_CONTEXT)
    {
        errno = EINVAL;
        return -1;
    }

    return eglMakeCurrent(
        egl_display,
        egl_surface,
        egl_surface,
        egl_context) == EGL_TRUE
        ? 0
        : -1;
}

int32_t swl_egl_make_current(
    swl_egl_display display,
    swl_egl_surface surface,
    swl_egl_context context)
{
    return swl_egl_make_current_impl(display, surface, context);
}

static int32_t swl_egl_clear_current_default(swl_egl_display display)
{
    EGLDisplay egl_display = swl_egl_cast_display(display);
    if (egl_display == EGL_NO_DISPLAY)
    {
        errno = EINVAL;
        return -1;
    }

    return eglMakeCurrent(
        egl_display,
        EGL_NO_SURFACE,
        EGL_NO_SURFACE,
        EGL_NO_CONTEXT) == EGL_TRUE
        ? 0
        : -1;
}

int32_t swl_egl_clear_current(swl_egl_display display)
{
    return swl_egl_clear_current_impl(display);
}

static int32_t swl_egl_swap_buffers_default(
    swl_egl_display display,
    swl_egl_surface surface)
{
    EGLDisplay egl_display = swl_egl_cast_display(display);
    EGLSurface egl_surface = swl_egl_cast_surface(surface);
    if (egl_display == EGL_NO_DISPLAY || egl_surface == EGL_NO_SURFACE)
    {
        errno = EINVAL;
        return -1;
    }

    return eglSwapBuffers(egl_display, egl_surface) == EGL_TRUE ? 0 : -1;
}

int32_t swl_egl_swap_buffers(
    swl_egl_display display,
    swl_egl_surface surface)
{
    return swl_egl_swap_buffers_impl(display, surface);
}

static int32_t swl_gles2_clear_rgba_default(
    uint32_t width,
    uint32_t height,
    float red,
    float green,
    float blue,
    float alpha)
{
    if (width == 0 || height == 0)
    {
        errno = EINVAL;
        return -1;
    }

    glViewport(0, 0, (GLsizei) width, (GLsizei) height);
    glClearColor(red, green, blue, alpha);
    glClear(GL_COLOR_BUFFER_BIT);
    return glGetError() == GL_NO_ERROR ? 0 : -1;
}

int32_t swl_gles2_clear_rgba(
    uint32_t width,
    uint32_t height,
    float red,
    float green,
    float blue,
    float alpha)
{
    return swl_gles2_clear_rgba_impl(width, height, red, green, blue, alpha);
}

static int32_t swl_gles2_read_center_pixel_rgba8_default(
    uint32_t width,
    uint32_t height,
    uint8_t *out_rgba)
{
    if (width == 0 || height == 0 || out_rgba == NULL)
    {
        errno = EINVAL;
        return -1;
    }

    glReadPixels(
        (GLint) (width / 2),
        (GLint) (height / 2),
        1,
        1,
        GL_RGBA,
        GL_UNSIGNED_BYTE,
        out_rgba);
    return glGetError() == GL_NO_ERROR ? 0 : -1;
}

int32_t swl_gles2_read_center_pixel_rgba8(
    uint32_t width,
    uint32_t height,
    uint8_t *out_rgba)
{
    return swl_gles2_read_center_pixel_rgba8_impl(width, height, out_rgba);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_egl_draw_recording_begin(
    int32_t clear_current_result,
    int32_t egl_error)
{
    swl_test_egl_draw_latest = (struct swl_test_egl_draw_record){0};
    swl_test_egl_clear_current_result = clear_current_result;
    swl_test_egl_error_value = egl_error;
    swl_egl_error_impl = swl_test_egl_error_record;
    swl_egl_make_current_impl = swl_test_egl_make_current_record;
    swl_egl_clear_current_impl = swl_test_egl_clear_current_record;
    swl_egl_swap_buffers_impl = swl_test_egl_swap_buffers_record;
    swl_gles2_clear_rgba_impl = swl_test_gles2_clear_rgba_record;
    swl_gles2_read_center_pixel_rgba8_impl =
        swl_test_gles2_read_center_pixel_rgba8_record;
}

void swl_test_egl_draw_recording_end(void)
{
    swl_egl_error_impl = swl_egl_error_default;
    swl_egl_make_current_impl = swl_egl_make_current_default;
    swl_egl_clear_current_impl = swl_egl_clear_current_default;
    swl_egl_swap_buffers_impl = swl_egl_swap_buffers_default;
    swl_gles2_clear_rgba_impl = swl_gles2_clear_rgba_default;
    swl_gles2_read_center_pixel_rgba8_impl =
        swl_gles2_read_center_pixel_rgba8_default;
}

struct swl_test_egl_draw_record swl_test_egl_draw_record(void)
{
    return swl_test_egl_draw_latest;
}
#endif
