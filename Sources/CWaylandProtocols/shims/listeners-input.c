#include "wayforge-shims.h"

static void swl_seat_handle_capabilities(
    void *data,
    struct wl_seat *seat,
    uint32_t capabilities)
{
    const struct swl_seat_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->capabilities != NULL)
    {
        callbacks->capabilities(callbacks->data, seat, capabilities);
    }
}

static void swl_seat_handle_name(
    void *data,
    struct wl_seat *seat,
    const char *name)
{
    const struct swl_seat_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->name != NULL)
    {
        callbacks->name(callbacks->data, seat, name);
    }
}

static const struct wl_seat_listener swl_seat_listener_impl = {
    .capabilities = swl_seat_handle_capabilities,
    .name = swl_seat_handle_name,
};

int swl_seat_add_listener(
    struct wl_seat *seat,
    const struct swl_seat_listener_callbacks *callbacks)
{
    return wl_seat_add_listener(
        seat,
        &swl_seat_listener_impl,
        (void *)callbacks);
}
