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

int32_t swl_egl_error(void)
{
    return (int32_t) eglGetError();
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

swl_egl_config swl_egl_choose_gles_window_config(swl_egl_display display)
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
    EGLConfig config = NULL;
    EGLint config_count = 0;
    if (eglChooseConfig(egl_display, attributes, &config, 1, &config_count) !=
        EGL_TRUE)
    {
        return NULL;
    }
    if (config_count <= 0 || config == NULL)
    {
        errno = ENODEV;
        return NULL;
    }

    return (swl_egl_config) config;
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

int32_t swl_egl_make_current(
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

int32_t swl_egl_clear_current(swl_egl_display display)
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

int32_t swl_egl_swap_buffers(
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

int32_t swl_gles2_clear_rgba(
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

int32_t swl_gles2_read_center_pixel_rgba8(
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
