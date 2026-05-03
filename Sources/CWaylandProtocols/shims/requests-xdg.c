#include "swift-wayland-shims.h"
#include "generated/xdg-decoration-unstable-v1-client-protocol.h"
#include "generated/xdg-shell-client-protocol.h"

struct xdg_surface *swl_xdg_wm_base_get_xdg_surface(
    struct xdg_wm_base *wm_base, struct wl_surface *surface)
{
    return xdg_wm_base_get_xdg_surface(wm_base, surface);
}

struct xdg_toplevel *swl_xdg_surface_get_toplevel(struct xdg_surface *xdg_surface)
{
    return xdg_surface_get_toplevel(xdg_surface);
}

void swl_xdg_wm_base_pong(struct xdg_wm_base *wm_base, uint32_t serial)
{
    xdg_wm_base_pong(wm_base, serial);
}

void swl_xdg_surface_ack_configure(struct xdg_surface *xdg_surface, uint32_t serial)
{
    xdg_surface_ack_configure(xdg_surface, serial);
}

void swl_xdg_toplevel_set_title(struct xdg_toplevel *xdg_toplevel, const char *title)
{
    xdg_toplevel_set_title(xdg_toplevel, title);
}

void swl_xdg_toplevel_set_app_id(struct xdg_toplevel *xdg_toplevel, const char *app_id)
{
    xdg_toplevel_set_app_id(xdg_toplevel, app_id);
}

void swl_xdg_surface_destroy(struct xdg_surface *xdg_surface)
{
    xdg_surface_destroy(xdg_surface);
}

void swl_xdg_toplevel_destroy(struct xdg_toplevel *xdg_toplevel)
{
    xdg_toplevel_destroy(xdg_toplevel);
}

void swl_xdg_wm_base_destroy(struct xdg_wm_base *wm_base)
{
    xdg_wm_base_destroy(wm_base);
}

struct zxdg_toplevel_decoration_v1 *swl_zxdg_decoration_manager_v1_get_toplevel_decoration(
    struct zxdg_decoration_manager_v1 *manager,
    struct xdg_toplevel *xdg_toplevel)
{
    return zxdg_decoration_manager_v1_get_toplevel_decoration(manager, xdg_toplevel);
}

void swl_zxdg_toplevel_decoration_v1_set_mode(
    struct zxdg_toplevel_decoration_v1 *decoration, uint32_t mode)
{
    zxdg_toplevel_decoration_v1_set_mode(decoration, mode);
}

void swl_zxdg_toplevel_decoration_v1_unset_mode(
    struct zxdg_toplevel_decoration_v1 *decoration)
{
    zxdg_toplevel_decoration_v1_unset_mode(decoration);
}

uint32_t swl_zxdg_toplevel_decoration_v1_mode_client_side(void)
{
    return ZXDG_TOPLEVEL_DECORATION_V1_MODE_CLIENT_SIDE;
}

uint32_t swl_zxdg_toplevel_decoration_v1_mode_server_side(void)
{
    return ZXDG_TOPLEVEL_DECORATION_V1_MODE_SERVER_SIDE;
}

void swl_zxdg_toplevel_decoration_v1_destroy(
    struct zxdg_toplevel_decoration_v1 *decoration)
{
    zxdg_toplevel_decoration_v1_destroy(decoration);
}

void swl_zxdg_decoration_manager_v1_destroy(
    struct zxdg_decoration_manager_v1 *manager)
{
    zxdg_decoration_manager_v1_destroy(manager);
}
