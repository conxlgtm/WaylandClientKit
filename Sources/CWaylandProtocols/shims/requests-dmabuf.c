#include "swift-wayland-shims.h"
#include "generated/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1-client-protocol.h"

struct zwp_linux_dmabuf_feedback_v1 *
swl_zwp_linux_dmabuf_v1_get_default_feedback(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf)
{
    return zwp_linux_dmabuf_v1_get_default_feedback(linux_dmabuf);
}

struct zwp_linux_dmabuf_feedback_v1 *
swl_zwp_linux_dmabuf_v1_get_surface_feedback(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf,
    struct wl_surface *surface)
{
    return zwp_linux_dmabuf_v1_get_surface_feedback(linux_dmabuf, surface);
}

struct zwp_linux_buffer_params_v1 *
swl_zwp_linux_dmabuf_v1_create_params(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf)
{
    return zwp_linux_dmabuf_v1_create_params(linux_dmabuf);
}

void swl_zwp_linux_buffer_params_v1_add(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t fd,
    uint32_t plane_idx,
    uint32_t offset,
    uint32_t stride,
    uint32_t modifier_hi,
    uint32_t modifier_lo)
{
    zwp_linux_buffer_params_v1_add(
        params,
        fd,
        plane_idx,
        offset,
        stride,
        modifier_hi,
        modifier_lo);
}

void swl_zwp_linux_buffer_params_v1_create(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t width,
    int32_t height,
    uint32_t format,
    uint32_t flags)
{
    zwp_linux_buffer_params_v1_create(params, width, height, format, flags);
}

void swl_zwp_linux_dmabuf_v1_destroy(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf)
{
    zwp_linux_dmabuf_v1_destroy(linux_dmabuf);
}

void swl_zwp_linux_buffer_params_v1_destroy(
    struct zwp_linux_buffer_params_v1 *params)
{
    zwp_linux_buffer_params_v1_destroy(params);
}

void swl_zwp_linux_dmabuf_feedback_v1_destroy(
    struct zwp_linux_dmabuf_feedback_v1 *feedback)
{
    zwp_linux_dmabuf_feedback_v1_destroy(feedback);
}
