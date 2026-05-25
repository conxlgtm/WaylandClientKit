#include "swift-wayland-shims.h"
#include "generated/staging/xdg-activation/xdg-activation-v1-client-protocol.h"

static void swl_xdg_activation_token_v1_handle_done(
    void *data,
    struct xdg_activation_token_v1 *token,
    const char *token_value)
{
    const struct swl_xdg_activation_token_v1_listener_callbacks *cb = data;
    if (cb && cb->done)
        cb->done(cb->data, token, token_value);
}

static const struct xdg_activation_token_v1_listener
    swl_xdg_activation_token_v1_listener_impl = {
        .done = swl_xdg_activation_token_v1_handle_done,
};

int swl_xdg_activation_token_v1_add_listener(
    struct xdg_activation_token_v1 *token,
    const struct swl_xdg_activation_token_v1_listener_callbacks *callbacks)
{
    return xdg_activation_token_v1_add_listener(
        token,
        &swl_xdg_activation_token_v1_listener_impl,
        (void *)callbacks);
}
