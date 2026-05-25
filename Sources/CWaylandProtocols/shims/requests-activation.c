#include "swift-wayland-shims.h"
#include "generated/staging/xdg-activation/xdg-activation-v1-client-protocol.h"

void swl_xdg_activation_v1_destroy(struct xdg_activation_v1 *activation)
{
    xdg_activation_v1_destroy(activation);
}

void swl_xdg_activation_token_v1_destroy(
    struct xdg_activation_token_v1 *token)
{
    xdg_activation_token_v1_destroy(token);
}
