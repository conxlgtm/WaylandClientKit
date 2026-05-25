#include "swift-wayland-shims.h"
#include "generated/staging/xdg-activation/xdg-activation-v1-client-protocol.h"

struct xdg_activation_token_v1 *swl_xdg_activation_v1_get_activation_token(
    struct xdg_activation_v1 *activation)
{
    return xdg_activation_v1_get_activation_token(activation);
}

void swl_xdg_activation_v1_activate(
    struct xdg_activation_v1 *activation,
    const char *token,
    struct wl_surface *surface)
{
    xdg_activation_v1_activate(activation, token, surface);
}

void swl_xdg_activation_v1_destroy(struct xdg_activation_v1 *activation)
{
    xdg_activation_v1_destroy(activation);
}

void swl_xdg_activation_token_v1_set_serial(
    struct xdg_activation_token_v1 *token,
    uint32_t serial,
    struct wl_seat *seat)
{
    xdg_activation_token_v1_set_serial(token, serial, seat);
}

void swl_xdg_activation_token_v1_set_app_id(
    struct xdg_activation_token_v1 *token,
    const char *app_id)
{
    xdg_activation_token_v1_set_app_id(token, app_id);
}

void swl_xdg_activation_token_v1_set_surface(
    struct xdg_activation_token_v1 *token,
    struct wl_surface *surface)
{
    xdg_activation_token_v1_set_surface(token, surface);
}

void swl_xdg_activation_token_v1_commit(
    struct xdg_activation_token_v1 *token)
{
    xdg_activation_token_v1_commit(token);
}

void swl_xdg_activation_token_v1_destroy(
    struct xdg_activation_token_v1 *token)
{
    xdg_activation_token_v1_destroy(token);
}
