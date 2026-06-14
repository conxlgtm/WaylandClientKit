#include "wayland-client-kit-shims.h"
#include "generated/stable/presentation-time/presentation-time-client-protocol.h"

#ifdef SWL_ENABLE_TESTING
static struct swl_test_presentation_listener_record
    swl_test_presentation_listener_latest;
static struct wp_presentation *swl_test_presentation_latest;
static const struct swl_wp_presentation_listener_callbacks
    *swl_test_presentation_callbacks_latest;
static struct wp_presentation_feedback *swl_test_presentation_feedback_latest;
static const struct swl_wp_presentation_feedback_listener_callbacks
    *swl_test_presentation_feedback_callbacks_latest;

static int swl_wp_presentation_add_listener_default(
    struct wp_presentation *presentation,
    const struct swl_wp_presentation_listener_callbacks *callbacks);
static int swl_wp_presentation_feedback_add_listener_default(
    struct wp_presentation_feedback *feedback,
    const struct swl_wp_presentation_feedback_listener_callbacks *callbacks);

static int (*swl_wp_presentation_add_listener_impl)(
    struct wp_presentation *presentation,
    const struct swl_wp_presentation_listener_callbacks *callbacks) =
        swl_wp_presentation_add_listener_default;
static int (*swl_wp_presentation_feedback_add_listener_impl)(
    struct wp_presentation_feedback *feedback,
    const struct swl_wp_presentation_feedback_listener_callbacks *callbacks) =
        swl_wp_presentation_feedback_add_listener_default;

static int swl_test_presentation_add_listener_record(
    struct wp_presentation *presentation,
    const struct swl_wp_presentation_listener_callbacks *callbacks)
{
    swl_test_presentation_listener_latest.call_count += 1;
    swl_test_presentation_listener_latest.object = presentation;
    swl_test_presentation_latest = presentation;
    swl_test_presentation_callbacks_latest = callbacks;
    return 0;
}

static int swl_test_presentation_feedback_add_listener_record(
    struct wp_presentation_feedback *feedback,
    const struct swl_wp_presentation_feedback_listener_callbacks *callbacks)
{
    swl_test_presentation_listener_latest.call_count += 1;
    swl_test_presentation_listener_latest.object = feedback;
    swl_test_presentation_feedback_latest = feedback;
    swl_test_presentation_feedback_callbacks_latest = callbacks;
    return 0;
}
#endif

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

static int swl_wp_presentation_add_listener_default(
    struct wp_presentation *presentation,
    const struct swl_wp_presentation_listener_callbacks *callbacks)
{
    return wp_presentation_add_listener(
        presentation,
        &swl_wp_presentation_listener_impl,
        (void *)callbacks);
}

#ifndef SWL_ENABLE_TESTING
#define swl_wp_presentation_add_listener_impl \
    swl_wp_presentation_add_listener_default
#endif

int swl_wp_presentation_add_listener(
    struct wp_presentation *presentation,
    const struct swl_wp_presentation_listener_callbacks *callbacks)
{
    return swl_wp_presentation_add_listener_impl(presentation, callbacks);
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

static int swl_wp_presentation_feedback_add_listener_default(
    struct wp_presentation_feedback *feedback,
    const struct swl_wp_presentation_feedback_listener_callbacks *callbacks)
{
    return wp_presentation_feedback_add_listener(
        feedback,
        &swl_wp_presentation_feedback_listener_impl,
        (void *)callbacks);
}

#ifndef SWL_ENABLE_TESTING
#define swl_wp_presentation_feedback_add_listener_impl \
    swl_wp_presentation_feedback_add_listener_default
#endif

int swl_wp_presentation_feedback_add_listener(
    struct wp_presentation_feedback *feedback,
    const struct swl_wp_presentation_feedback_listener_callbacks *callbacks)
{
    return swl_wp_presentation_feedback_add_listener_impl(feedback, callbacks);
}

#ifdef SWL_ENABLE_TESTING
void swl_test_presentation_listener_recording_begin(void)
{
    swl_test_presentation_listener_latest =
        (struct swl_test_presentation_listener_record){0};
    swl_test_presentation_latest = NULL;
    swl_test_presentation_callbacks_latest = NULL;
    swl_test_presentation_feedback_latest = NULL;
    swl_test_presentation_feedback_callbacks_latest = NULL;
    swl_wp_presentation_add_listener_impl =
        swl_test_presentation_add_listener_record;
    swl_wp_presentation_feedback_add_listener_impl =
        swl_test_presentation_feedback_add_listener_record;
}

void swl_test_presentation_listener_recording_end(void)
{
    swl_wp_presentation_add_listener_impl =
        swl_wp_presentation_add_listener_default;
    swl_wp_presentation_feedback_add_listener_impl =
        swl_wp_presentation_feedback_add_listener_default;
    swl_test_presentation_latest = NULL;
    swl_test_presentation_callbacks_latest = NULL;
    swl_test_presentation_feedback_latest = NULL;
    swl_test_presentation_feedback_callbacks_latest = NULL;
}

struct swl_test_presentation_listener_record
swl_test_presentation_listener_record(void)
{
    return swl_test_presentation_listener_latest;
}

int swl_test_presentation_feedback_listener_emit_sync_output(
    struct wl_output *output)
{
    if (!swl_test_presentation_feedback_callbacks_latest ||
        !swl_test_presentation_feedback_latest)
        return 0;

    swl_wp_presentation_feedback_handle_sync_output(
        (void *)swl_test_presentation_feedback_callbacks_latest,
        swl_test_presentation_feedback_latest,
        output);
    return 1;
}

int swl_test_presentation_feedback_listener_emit_presented(
    uint32_t tv_sec_hi,
    uint32_t tv_sec_lo,
    uint32_t tv_nsec,
    uint32_t refresh,
    uint32_t seq_hi,
    uint32_t seq_lo,
    uint32_t flags)
{
    if (!swl_test_presentation_feedback_callbacks_latest ||
        !swl_test_presentation_feedback_latest)
        return 0;

    swl_wp_presentation_feedback_handle_presented(
        (void *)swl_test_presentation_feedback_callbacks_latest,
        swl_test_presentation_feedback_latest,
        tv_sec_hi,
        tv_sec_lo,
        tv_nsec,
        refresh,
        seq_hi,
        seq_lo,
        flags);
    return 1;
}

int swl_test_presentation_feedback_listener_emit_discarded(void)
{
    if (!swl_test_presentation_feedback_callbacks_latest ||
        !swl_test_presentation_feedback_latest)
        return 0;

    swl_wp_presentation_feedback_handle_discarded(
        (void *)swl_test_presentation_feedback_callbacks_latest,
        swl_test_presentation_feedback_latest);
    return 1;
}
#endif
