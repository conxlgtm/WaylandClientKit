#include "swift-wayland-shims.h"
#include "generated/fractional-scale-v1-client-protocol.h"

static void swl_wp_fractional_scale_v1_handle_preferred_scale(
    void *data, struct wp_fractional_scale_v1 *fractional_scale, uint32_t scale)
{
    const struct swl_wp_fractional_scale_v1_listener_callbacks *cb = data;
    if (cb && cb->preferred_scale)
        cb->preferred_scale(cb->data, fractional_scale, scale);
}

static const struct wp_fractional_scale_v1_listener
    swl_wp_fractional_scale_v1_listener_impl = {
        .preferred_scale = swl_wp_fractional_scale_v1_handle_preferred_scale,
};

int swl_wp_fractional_scale_v1_add_listener(
    struct wp_fractional_scale_v1 *fractional_scale,
    const struct swl_wp_fractional_scale_v1_listener_callbacks *callbacks)
{
    return wp_fractional_scale_v1_add_listener(
        fractional_scale,
        &swl_wp_fractional_scale_v1_listener_impl,
        (void *)callbacks);
}

#ifdef SWL_ENABLE_TESTING
static struct swl_test_fractional_preferred_scale_record
    swl_test_fractional_preferred_scale_latest;

static void swl_test_record_fractional_preferred_scale(
    void *data, struct wp_fractional_scale_v1 *fractional_scale, uint32_t scale)
{
    swl_test_fractional_preferred_scale_latest.call_count += 1;
    swl_test_fractional_preferred_scale_latest.data = data;
    swl_test_fractional_preferred_scale_latest.fractional_scale = fractional_scale;
    swl_test_fractional_preferred_scale_latest.scale = scale;
}

void swl_test_fractional_scale_listener_emit_preferred_scale(
    void *data,
    struct wp_fractional_scale_v1 *fractional_scale,
    uint32_t scale,
    struct swl_test_fractional_preferred_scale_record *record)
{
    swl_test_fractional_preferred_scale_latest =
        (struct swl_test_fractional_preferred_scale_record){0};

    const struct swl_wp_fractional_scale_v1_listener_callbacks callbacks = {
        .preferred_scale = swl_test_record_fractional_preferred_scale,
        .data = data,
    };

    swl_wp_fractional_scale_v1_handle_preferred_scale(
        (void *)&callbacks, fractional_scale, scale);

    if (record)
        *record = swl_test_fractional_preferred_scale_latest;
}
#endif
