#include "swift-wayland-shims.h"
#include "generated/fractional-scale-v1-client-protocol.h"
#include "generated/viewporter-client-protocol.h"

struct wp_viewport *swl_wp_viewporter_get_viewport(
    struct wp_viewporter *viewporter,
    struct wl_surface *surface)
{
    return wp_viewporter_get_viewport(viewporter, surface);
}

void swl_wp_viewport_set_destination(
    struct wp_viewport *viewport,
    int32_t width,
    int32_t height)
{
    wp_viewport_set_destination(viewport, width, height);
}

void swl_wp_viewport_destroy(struct wp_viewport *viewport)
{
    wp_viewport_destroy(viewport);
}

void swl_wp_viewporter_destroy(struct wp_viewporter *viewporter)
{
    wp_viewporter_destroy(viewporter);
}

struct wp_fractional_scale_v1 *swl_wp_fractional_scale_manager_v1_get_fractional_scale(
    struct wp_fractional_scale_manager_v1 *manager,
    struct wl_surface *surface)
{
    return wp_fractional_scale_manager_v1_get_fractional_scale(manager, surface);
}

void swl_wp_fractional_scale_v1_destroy(struct wp_fractional_scale_v1 *fractional_scale)
{
    wp_fractional_scale_v1_destroy(fractional_scale);
}

void swl_wp_fractional_scale_manager_v1_destroy(
    struct wp_fractional_scale_manager_v1 *manager)
{
    wp_fractional_scale_manager_v1_destroy(manager);
}
