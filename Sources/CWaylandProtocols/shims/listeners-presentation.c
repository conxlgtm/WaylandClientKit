#include "swift-wayland-shims.h"
#include "generated/stable/presentation-time/presentation-time-client-protocol.h"

static void swl_wp_presentation_handle_clock_id(
    void *data, struct wp_presentation *presentation, uint32_t clock_id)
{
    const struct swl_wp_presentation_listener_callbacks *cb = data;
    if (cb && cb->clock_id)
        cb->clock_id(cb->data, presentation, clock_id);
}

static const struct wp_presentation_listener swl_wp_presentation_listener_impl = {
    .clock_id = swl_wp_presentation_handle_clock_id,
};

int swl_wp_presentation_add_listener(
    struct wp_presentation *presentation,
    const struct swl_wp_presentation_listener_callbacks *callbacks)
{
    return wp_presentation_add_listener(
        presentation,
        &swl_wp_presentation_listener_impl,
        (void *)callbacks);
}

static void swl_wp_presentation_feedback_handle_sync_output(
    void *data,
    struct wp_presentation_feedback *feedback,
    struct wl_output *output)
{
    const struct swl_wp_presentation_feedback_listener_callbacks *cb = data;
    if (cb && cb->sync_output)
        cb->sync_output(cb->data, feedback, output);
}

static void swl_wp_presentation_feedback_handle_presented(
    void *data,
    struct wp_presentation_feedback *feedback,
    uint32_t tv_sec_hi,
    uint32_t tv_sec_lo,
    uint32_t tv_nsec,
    uint32_t refresh,
    uint32_t seq_hi,
    uint32_t seq_lo,
    uint32_t flags)
{
    const struct swl_wp_presentation_feedback_listener_callbacks *cb = data;
    if (cb && cb->presented)
        cb->presented(
            cb->data,
            feedback,
            tv_sec_hi,
            tv_sec_lo,
            tv_nsec,
            refresh,
            seq_hi,
            seq_lo,
            flags);
}

static void swl_wp_presentation_feedback_handle_discarded(
    void *data, struct wp_presentation_feedback *feedback)
{
    const struct swl_wp_presentation_feedback_listener_callbacks *cb = data;
    if (cb && cb->discarded)
        cb->discarded(cb->data, feedback);
}

static const struct wp_presentation_feedback_listener
    swl_wp_presentation_feedback_listener_impl = {
        .sync_output = swl_wp_presentation_feedback_handle_sync_output,
        .presented = swl_wp_presentation_feedback_handle_presented,
        .discarded = swl_wp_presentation_feedback_handle_discarded,
};

int swl_wp_presentation_feedback_add_listener(
    struct wp_presentation_feedback *feedback,
    const struct swl_wp_presentation_feedback_listener_callbacks *callbacks)
{
    return wp_presentation_feedback_add_listener(
        feedback,
        &swl_wp_presentation_feedback_listener_impl,
        (void *)callbacks);
}
