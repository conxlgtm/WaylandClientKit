#include "swift-wayland-shims.h"
#include "generated/xdg-shell-client-protocol.h"

/*
 * xdg_wm_base listener bridge
 */

static void swl_xdg_wm_base_handle_ping(
    void *data, struct xdg_wm_base *wm_base, uint32_t serial)
{
    const struct swl_xdg_wm_base_listener_callbacks *cb = data;
    if (cb && cb->ping)
        cb->ping(cb->data, wm_base, serial);
}

static const struct xdg_wm_base_listener swl_xdg_wm_base_listener_impl = {
    .ping = swl_xdg_wm_base_handle_ping,
};

int swl_xdg_wm_base_add_listener(
    struct xdg_wm_base *wm_base,
    const struct swl_xdg_wm_base_listener_callbacks *callbacks)
{
    return xdg_wm_base_add_listener(
        wm_base, &swl_xdg_wm_base_listener_impl, (void *)callbacks);
}

/*
 * xdg_surface listener bridge
 */

static void swl_xdg_surface_handle_configure(
    void *data, struct xdg_surface *xdg_surface, uint32_t serial)
{
    const struct swl_xdg_surface_listener_callbacks *cb = data;
    if (cb && cb->configure)
        cb->configure(cb->data, xdg_surface, serial);
}

static const struct xdg_surface_listener swl_xdg_surface_listener_impl = {
    .configure = swl_xdg_surface_handle_configure,
};

int swl_xdg_surface_add_listener(
    struct xdg_surface *xdg_surface,
    const struct swl_xdg_surface_listener_callbacks *callbacks)
{
    return xdg_surface_add_listener(
        xdg_surface, &swl_xdg_surface_listener_impl, (void *)callbacks);
}

/*
 * xdg_toplevel listener bridge
 */

static void swl_xdg_toplevel_handle_configure(
    void *data, struct xdg_toplevel *xdg_toplevel,
    int32_t width, int32_t height, struct wl_array *states)
{
    const struct swl_xdg_toplevel_listener_callbacks *cb = data;
    if (cb && cb->configure)
        cb->configure(cb->data, xdg_toplevel, width, height, states);
}

static void swl_xdg_toplevel_handle_close(
    void *data, struct xdg_toplevel *xdg_toplevel)
{
    const struct swl_xdg_toplevel_listener_callbacks *cb = data;
    if (cb && cb->close)
        cb->close(cb->data, xdg_toplevel);
}

static void swl_xdg_toplevel_handle_configure_bounds(
    void *data, struct xdg_toplevel *xdg_toplevel,
    int32_t width, int32_t height)
{
    const struct swl_xdg_toplevel_listener_callbacks *cb = data;
    if (cb && cb->configure_bounds)
        cb->configure_bounds(cb->data, xdg_toplevel, width, height);
}

static void swl_xdg_toplevel_handle_wm_capabilities(
    void *data, struct xdg_toplevel *xdg_toplevel,
    struct wl_array *capabilities)
{
    const struct swl_xdg_toplevel_listener_callbacks *cb = data;
    if (cb && cb->wm_capabilities)
        cb->wm_capabilities(cb->data, xdg_toplevel, capabilities);
}

static const struct xdg_toplevel_listener swl_xdg_toplevel_listener_impl = {
    .configure       = swl_xdg_toplevel_handle_configure,
    .close           = swl_xdg_toplevel_handle_close,
    .configure_bounds = swl_xdg_toplevel_handle_configure_bounds,
    .wm_capabilities = swl_xdg_toplevel_handle_wm_capabilities,
};

int swl_xdg_toplevel_add_listener(
    struct xdg_toplevel *xdg_toplevel,
    const struct swl_xdg_toplevel_listener_callbacks *callbacks)
{
    return xdg_toplevel_add_listener(
        xdg_toplevel, &swl_xdg_toplevel_listener_impl, (void *)callbacks);
}
