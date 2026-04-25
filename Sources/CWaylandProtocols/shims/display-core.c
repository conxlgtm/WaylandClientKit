#include "swift-wayland-shims.h"
#include "generated/wayland-client-protocol.h"

struct wl_registry *swl_display_get_registry(struct wl_display *display)
{
    return wl_display_get_registry(display);
}

struct wl_callback *swl_display_sync(struct wl_display *display)
{
    return wl_display_sync(display);
}

int swl_display_get_protocol_error_details(
    struct wl_display *display, struct swl_protocol_error_details *details)
{
    const struct wl_interface *interface = NULL;
    uint32_t object_id = 0;
    int code = wl_display_get_protocol_error(display, &interface, &object_id);

    if (details == NULL)
        return code;

    details->code = code;
    details->object_id = object_id;
    details->interface_name = interface != NULL ? interface->name : NULL;
    return code;
}
