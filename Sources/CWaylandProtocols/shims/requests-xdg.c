#include "wayforge-shims.h"
#include "generated/xdg-shell-client-protocol.h"

struct xdg_surface *swl_xdg_wm_base_get_xdg_surface(
    struct xdg_wm_base *wm_base,
    struct wl_surface *surface)
{
    return xdg_wm_base_get_xdg_surface(wm_base, surface);
}
struct xdg_toplevel *swl_xdg_surface_get_toplevel(
    struct xdg_surface *xdg_surface)
{
    return xdg_surface_get_toplevel(xdg_surface);
}
void swl_xdg_wm_base_pong(
    struct xdg_wm_base *wm_base,
    uint32_t serial)
{
    xdg_wm_base_pong(wm_base, serial);
}
void swl_xdg_surface_ack_configure(
    struct xdg_surface *xdg_surface,
    uint32_t serial)
{
    xdg_surface_ack_configure(xdg_surface, serial);
}
void swl_xdg_toplevel_set_title(
    struct xdg_toplevel *xdg_toplevel,
    const char *title)
{
    xdg_toplevel_set_title(xdg_toplevel, title);
}

void swl_xdg_toplevel_set_app_id(
    struct xdg_toplevel *xdg_toplevel,
    const char *app_id)
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
