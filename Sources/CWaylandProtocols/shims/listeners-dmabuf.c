#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1-client-protocol.h"

static void swl_zwp_linux_dmabuf_feedback_v1_handle_done(
    void *data, struct zwp_linux_dmabuf_feedback_v1 *feedback)
{
    const struct swl_zwp_linux_dmabuf_feedback_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, feedback);
}

static void swl_zwp_linux_dmabuf_feedback_v1_handle_format_table(
    void *data,
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    int32_t fd,
    uint32_t size)
{
    const struct swl_zwp_linux_dmabuf_feedback_listener_callbacks *cb = data;
    if (cb && cb->format_table)
        cb->format_table(cb->data, feedback, fd, size);
}

static void swl_zwp_linux_dmabuf_feedback_v1_handle_main_device(
    void *data,
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    struct wl_array *device)
{
    const struct swl_zwp_linux_dmabuf_feedback_listener_callbacks *cb = data;
    if (cb && cb->main_device)
        cb->main_device(cb->data, feedback, device);
}

static void swl_zwp_linux_dmabuf_feedback_v1_handle_tranche_done(
    void *data, struct zwp_linux_dmabuf_feedback_v1 *feedback)
{
    const struct swl_zwp_linux_dmabuf_feedback_listener_callbacks *cb = data;
    if (cb && cb->tranche_done)
        cb->tranche_done(cb->data, feedback);
}

static void swl_zwp_linux_dmabuf_feedback_v1_handle_tranche_target_device(
    void *data,
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    struct wl_array *device)
{
    const struct swl_zwp_linux_dmabuf_feedback_listener_callbacks *cb = data;
    if (cb && cb->tranche_target_device)
        cb->tranche_target_device(cb->data, feedback, device);
}

static void swl_zwp_linux_dmabuf_feedback_v1_handle_tranche_formats(
    void *data,
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    struct wl_array *indices)
{
    const struct swl_zwp_linux_dmabuf_feedback_listener_callbacks *cb = data;
    if (cb && cb->tranche_formats)
        cb->tranche_formats(cb->data, feedback, indices);
}

static void swl_zwp_linux_dmabuf_feedback_v1_handle_tranche_flags(
    void *data,
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    uint32_t flags)
{
    const struct swl_zwp_linux_dmabuf_feedback_listener_callbacks *cb = data;
    if (cb && cb->tranche_flags)
        cb->tranche_flags(cb->data, feedback, flags);
}

static const struct zwp_linux_dmabuf_feedback_v1_listener
    swl_zwp_linux_dmabuf_feedback_v1_listener_impl = {
        .done = swl_zwp_linux_dmabuf_feedback_v1_handle_done,
        .format_table = swl_zwp_linux_dmabuf_feedback_v1_handle_format_table,
        .main_device = swl_zwp_linux_dmabuf_feedback_v1_handle_main_device,
        .tranche_done = swl_zwp_linux_dmabuf_feedback_v1_handle_tranche_done,
        .tranche_target_device =
            swl_zwp_linux_dmabuf_feedback_v1_handle_tranche_target_device,
        .tranche_formats = swl_zwp_linux_dmabuf_feedback_v1_handle_tranche_formats,
        .tranche_flags = swl_zwp_linux_dmabuf_feedback_v1_handle_tranche_flags,
};

int swl_zwp_linux_dmabuf_feedback_v1_add_listener(
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    const struct swl_zwp_linux_dmabuf_feedback_listener_callbacks *callbacks)
{
    return zwp_linux_dmabuf_feedback_v1_add_listener(
        feedback,
        &swl_zwp_linux_dmabuf_feedback_v1_listener_impl,
        (void *)callbacks);
}

static void swl_zwp_linux_buffer_params_v1_handle_created(
    void *data,
    struct zwp_linux_buffer_params_v1 *params,
    struct wl_buffer *buffer)
{
    const struct swl_zwp_linux_buffer_params_listener_callbacks *cb = data;
    if (cb && cb->created)
        cb->created(cb->data, params, buffer);
}

static void swl_zwp_linux_buffer_params_v1_handle_failed(
    void *data, struct zwp_linux_buffer_params_v1 *params)
{
    const struct swl_zwp_linux_buffer_params_listener_callbacks *cb = data;
    if (cb && cb->failed)
        cb->failed(cb->data, params);
}

static const struct zwp_linux_buffer_params_v1_listener
    swl_zwp_linux_buffer_params_v1_listener_impl = {
        .created = swl_zwp_linux_buffer_params_v1_handle_created,
        .failed = swl_zwp_linux_buffer_params_v1_handle_failed,
};

int swl_zwp_linux_buffer_params_v1_add_listener(
    struct zwp_linux_buffer_params_v1 *params,
    const struct swl_zwp_linux_buffer_params_listener_callbacks *callbacks)
{
    return zwp_linux_buffer_params_v1_add_listener(
        params,
        &swl_zwp_linux_buffer_params_v1_listener_impl,
        (void *)callbacks);
}
