#include "swift-wayland-shims.h"
#include "generated/core/wayland-client-protocol.h"

struct wl_registry *swl_display_get_registry(struct wl_display *display)
{
    return wl_display_get_registry(display);
}

struct wl_callback *swl_display_sync(struct wl_display *display)
{
    return wl_display_sync(display);
}

struct wl_event_queue *swl_display_create_event_queue(struct wl_display *display)
{
    return wl_display_create_queue(display);
}

void swl_event_queue_destroy(struct wl_event_queue *queue)
{
    wl_event_queue_destroy(queue);
}

struct wl_display *swl_display_create_wrapper(struct wl_display *display)
{
    return wl_proxy_create_wrapper(display);
}

void swl_display_wrapper_set_queue(
    struct wl_display *display_wrapper,
    struct wl_event_queue *queue)
{
    wl_proxy_set_queue((struct wl_proxy *)display_wrapper, queue);
}

void swl_display_wrapper_destroy(struct wl_display *display_wrapper)
{
    wl_proxy_wrapper_destroy(display_wrapper);
}

int swl_display_dispatch_event_queue_pending(
    struct wl_display *display,
    struct wl_event_queue *queue)
{
    return wl_display_dispatch_queue_pending(display, queue);
}

int swl_display_prepare_read_event_queue(
    struct wl_display *display,
    struct wl_event_queue *queue)
{
    return wl_display_prepare_read_queue(display, queue);
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
