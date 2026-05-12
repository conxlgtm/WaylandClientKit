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

void swl_zwp_linux_dmabuf_v1_destroy(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf)
{
    zwp_linux_dmabuf_v1_destroy(linux_dmabuf);
}

void swl_zwp_linux_dmabuf_feedback_v1_destroy(
    struct zwp_linux_dmabuf_feedback_v1 *feedback)
{
    zwp_linux_dmabuf_feedback_v1_destroy(feedback);
}
