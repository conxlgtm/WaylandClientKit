#include "swift-wayland-shims.h"
#include "generated/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1-client-protocol.h"

static void swl_xdg_toplevel_icon_manager_v1_handle_icon_size(
    void *data,
    struct xdg_toplevel_icon_manager_v1 *manager,
    int32_t size)
{
    const struct swl_xdg_toplevel_icon_manager_v1_listener_callbacks *callbacks =
        data;
    if (callbacks != NULL && callbacks->icon_size != NULL) {
        callbacks->icon_size(callbacks->data, manager, size);
    }
}

static void swl_xdg_toplevel_icon_manager_v1_handle_done(
    void *data,
    struct xdg_toplevel_icon_manager_v1 *manager)
{
    const struct swl_xdg_toplevel_icon_manager_v1_listener_callbacks *callbacks =
        data;
    if (callbacks != NULL && callbacks->done != NULL) {
        callbacks->done(callbacks->data, manager);
    }
}

static const struct xdg_toplevel_icon_manager_v1_listener
    swl_xdg_toplevel_icon_manager_v1_listener_impl = {
        .icon_size = swl_xdg_toplevel_icon_manager_v1_handle_icon_size,
        .done = swl_xdg_toplevel_icon_manager_v1_handle_done,
    };

int swl_xdg_toplevel_icon_manager_v1_add_listener(
    struct xdg_toplevel_icon_manager_v1 *manager,
    const struct swl_xdg_toplevel_icon_manager_v1_listener_callbacks *callbacks)
{
    return xdg_toplevel_icon_manager_v1_add_listener(
        manager,
        &swl_xdg_toplevel_icon_manager_v1_listener_impl,
        (void *)callbacks);
}
