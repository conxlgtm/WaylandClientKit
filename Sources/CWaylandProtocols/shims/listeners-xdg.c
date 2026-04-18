#include "wayforge-shims.h"
#include "generated/xdg-shell-client-protocol.h"

/*
 * xdg_wm_base listener bridge
 */
static void swl_xdg_wm_base_handle_ping(
    void *data,
    struct xdg_wm_base *wm_base,
    uint32_t serial)
{
    const struct swl_xdg_wm_base_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->ping != NULL)
    {
        callbacks->ping(callbacks->data, wm_base, serial);
    }
}
static const struct xdg_wm_base_listener swl_xdg_wm_base_listener_impl = {
    .ping = swl_xdg_wm_base_handle_ping,
};
int swl_xdg_wm_base_add_listener(
    struct xdg_wm_base *wm_base,
    const struct swl_xdg_wm_base_listener_callbacks *callbacks)
{
    return xdg_wm_base_add_listener(
        wm_base,
        &swl_xdg_wm_base_listener_impl,
        (void *)callbacks);
}
/*
 * xdg_surface listener bridge
 */
static void swl_xdg_surface_handle_configure(
    void *data,
    struct xdg_surface *xdg_surface,
    uint32_t serial)
{
    const struct swl_xdg_surface_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->configure != NULL)
    {
        callbacks->configure(callbacks->data, xdg_surface, serial);
    }
}
static const struct xdg_surface_listener swl_xdg_surface_listener_impl = {
    .configure = swl_xdg_surface_handle_configure,
};
int swl_xdg_surface_add_listener(
    struct xdg_surface *xdg_surface,
    const struct swl_xdg_surface_listener_callbacks *callbacks)
{
    return xdg_surface_add_listener(
        xdg_surface,
        &swl_xdg_surface_listener_impl,
        (void *)callbacks);
}
/*
 * xdg_toplevel listener bridge
 */
static void swl_xdg_toplevel_handle_configure(
    void *data,
    struct xdg_toplevel *xdg_toplevel,
    int32_t width,
    int32_t height,
    struct wl_array *states)
{
    const struct swl_xdg_toplevel_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->configure != NULL)
    {
        callbacks->configure(
            callbacks->data,
            xdg_toplevel,
            width,
            height,
            states);
    }
}
static void swl_xdg_toplevel_handle_close(
    void *data,
    struct xdg_toplevel *xdg_toplevel)
{
    const struct swl_xdg_toplevel_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->close != NULL)
    {
        callbacks->close(callbacks->data, xdg_toplevel);
    }
}
static void swl_xdg_toplevel_handle_configure_bounds(
    void *data,
    struct xdg_toplevel *xdg_toplevel,
    int32_t width,
    int32_t height)
{
    const struct swl_xdg_toplevel_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->configure_bounds != NULL)
    {
        callbacks->configure_bounds(callbacks->data, xdg_toplevel, width, height);
    }
}
static void swl_xdg_toplevel_handle_wm_capabilities(
    void *data,
    struct xdg_toplevel *xdg_toplevel,
    struct wl_array *capabilities)
{
    const struct swl_xdg_toplevel_listener_callbacks *callbacks = data;
    if (callbacks != NULL && callbacks->wm_capabilities != NULL)
    {
        callbacks->wm_capabilities(callbacks->data, xdg_toplevel, capabilities);
    }
}
static const struct xdg_toplevel_listener swl_xdg_toplevel_listener_impl = {
    .configure = swl_xdg_toplevel_handle_configure,
    .close = swl_xdg_toplevel_handle_close,
    .configure_bounds = swl_xdg_toplevel_handle_configure_bounds,
    .wm_capabilities = swl_xdg_toplevel_handle_wm_capabilities,
};
int swl_xdg_toplevel_add_listener(
    struct xdg_toplevel *xdg_toplevel,
    const struct swl_xdg_toplevel_listener_callbacks *callbacks)
{
    return xdg_toplevel_add_listener(
        xdg_toplevel,
        &swl_xdg_toplevel_listener_impl,
        (void *)callbacks);
}
