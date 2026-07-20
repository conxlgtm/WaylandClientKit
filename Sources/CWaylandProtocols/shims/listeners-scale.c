#include "wayland-client-kit-shims.h"
#include "generated/staging/fractional-scale/fractional-scale-v1-client-protocol.h"

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

    callbacks.preferred_scale(callbacks.data, fractional_scale, scale);

    if (record)
        *record = swl_test_fractional_preferred_scale_latest;
}
#endif
