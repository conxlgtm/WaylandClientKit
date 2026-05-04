#include "swift-wayland-shims.h"
#include "generated/xdg-decoration-unstable-v1-client-protocol.h"
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

/*
 * xdg_popup listener bridge
 */

static void swl_xdg_popup_handle_configure(
    void *data,
    struct xdg_popup *popup,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    const struct swl_xdg_popup_listener_callbacks *cb = data;
    if (cb && cb->configure)
        cb->configure(cb->data, popup, x, y, width, height);
}

static void swl_xdg_popup_handle_done(
    void *data,
    struct xdg_popup *popup)
{
    const struct swl_xdg_popup_listener_callbacks *cb = data;
    if (cb && cb->popup_done)
        cb->popup_done(cb->data, popup);
}

static void swl_xdg_popup_handle_repositioned(
    void *data,
    struct xdg_popup *popup,
    uint32_t token)
{
    const struct swl_xdg_popup_listener_callbacks *cb = data;
    if (cb && cb->repositioned)
        cb->repositioned(cb->data, popup, token);
}

static const struct xdg_popup_listener swl_xdg_popup_listener_impl = {
    .configure    = swl_xdg_popup_handle_configure,
    .popup_done   = swl_xdg_popup_handle_done,
    .repositioned = swl_xdg_popup_handle_repositioned,
};

int swl_xdg_popup_add_listener(
    struct xdg_popup *popup,
    const struct swl_xdg_popup_listener_callbacks *callbacks)
{
    return xdg_popup_add_listener(
        popup, &swl_xdg_popup_listener_impl, (void *)callbacks);
}

/*
 * zxdg_toplevel_decoration_v1 listener bridge
 */

static void swl_zxdg_toplevel_decoration_v1_handle_configure(
    void *data, struct zxdg_toplevel_decoration_v1 *decoration, uint32_t mode)
{
    const struct swl_zxdg_toplevel_decoration_v1_listener_callbacks *cb = data;
    if (cb && cb->configure)
        cb->configure(cb->data, decoration, mode);
}

static const struct zxdg_toplevel_decoration_v1_listener
    swl_zxdg_toplevel_decoration_v1_listener_impl = {
        .configure = swl_zxdg_toplevel_decoration_v1_handle_configure,
};

int swl_zxdg_toplevel_decoration_v1_add_listener(
    struct zxdg_toplevel_decoration_v1 *decoration,
    const struct swl_zxdg_toplevel_decoration_v1_listener_callbacks *callbacks)
{
    return zxdg_toplevel_decoration_v1_add_listener(
        decoration, &swl_zxdg_toplevel_decoration_v1_listener_impl, (void *)callbacks);
}

#ifdef SWL_ENABLE_TESTING
static struct swl_test_xdg_popup_configure_record
    swl_test_xdg_popup_configure_latest;
static struct swl_test_xdg_popup_done_record swl_test_xdg_popup_done_latest;
static struct swl_test_xdg_popup_repositioned_record
    swl_test_xdg_popup_repositioned_latest;

static void swl_test_record_xdg_popup_configure(
    void *data,
    struct xdg_popup *popup,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_test_xdg_popup_configure_latest.call_count += 1;
    swl_test_xdg_popup_configure_latest.data = data;
    swl_test_xdg_popup_configure_latest.popup = popup;
    swl_test_xdg_popup_configure_latest.x = x;
    swl_test_xdg_popup_configure_latest.y = y;
    swl_test_xdg_popup_configure_latest.width = width;
    swl_test_xdg_popup_configure_latest.height = height;
}

static void swl_test_record_xdg_popup_done(
    void *data,
    struct xdg_popup *popup)
{
    swl_test_xdg_popup_done_latest.call_count += 1;
    swl_test_xdg_popup_done_latest.data = data;
    swl_test_xdg_popup_done_latest.popup = popup;
}

static void swl_test_record_xdg_popup_repositioned(
    void *data,
    struct xdg_popup *popup,
    uint32_t token)
{
    swl_test_xdg_popup_repositioned_latest.call_count += 1;
    swl_test_xdg_popup_repositioned_latest.data = data;
    swl_test_xdg_popup_repositioned_latest.popup = popup;
    swl_test_xdg_popup_repositioned_latest.token = token;
}

void swl_test_xdg_popup_listener_emit_configure(
    void *data,
    struct xdg_popup *popup,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height,
    struct swl_test_xdg_popup_configure_record *record)
{
    swl_test_xdg_popup_configure_latest =
        (struct swl_test_xdg_popup_configure_record){0};

    const struct swl_xdg_popup_listener_callbacks callbacks = {
        .configure = swl_test_record_xdg_popup_configure,
        .data = data,
    };

    swl_xdg_popup_handle_configure((void *)&callbacks, popup, x, y, width, height);

    if (record)
        *record = swl_test_xdg_popup_configure_latest;
}

void swl_test_xdg_popup_listener_emit_done(
    void *data,
    struct xdg_popup *popup,
    struct swl_test_xdg_popup_done_record *record)
{
    swl_test_xdg_popup_done_latest =
        (struct swl_test_xdg_popup_done_record){0};

    const struct swl_xdg_popup_listener_callbacks callbacks = {
        .popup_done = swl_test_record_xdg_popup_done,
        .data = data,
    };

    swl_xdg_popup_handle_done((void *)&callbacks, popup);

    if (record)
        *record = swl_test_xdg_popup_done_latest;
}

void swl_test_xdg_popup_listener_emit_repositioned(
    void *data,
    struct xdg_popup *popup,
    uint32_t token,
    struct swl_test_xdg_popup_repositioned_record *record)
{
    swl_test_xdg_popup_repositioned_latest =
        (struct swl_test_xdg_popup_repositioned_record){0};

    const struct swl_xdg_popup_listener_callbacks callbacks = {
        .repositioned = swl_test_record_xdg_popup_repositioned,
        .data = data,
    };

    swl_xdg_popup_handle_repositioned((void *)&callbacks, popup, token);

    if (record)
        *record = swl_test_xdg_popup_repositioned_latest;
}
#endif
