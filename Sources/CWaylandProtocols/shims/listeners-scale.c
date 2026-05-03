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
