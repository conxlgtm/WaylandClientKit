#include "wayland-client-kit-shims.h"
#include "generated/staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1-client-protocol.h"
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

static void swl_ext_foreign_toplevel_list_v1_handle_toplevel(
    void *data,
    struct ext_foreign_toplevel_list_v1 *list,
    struct ext_foreign_toplevel_handle_v1 *toplevel)
{
    const struct swl_ext_foreign_toplevel_list_v1_listener_callbacks *cb =
        data;
    if (cb != NULL && cb->toplevel != NULL) {
        cb->toplevel(cb->data, list, toplevel);
    }
}

static void swl_ext_foreign_toplevel_list_v1_handle_finished(
    void *data,
    struct ext_foreign_toplevel_list_v1 *list)
{
    const struct swl_ext_foreign_toplevel_list_v1_listener_callbacks *cb =
        data;
    if (cb != NULL && cb->finished != NULL) {
        cb->finished(cb->data, list);
    }
}

static const struct ext_foreign_toplevel_list_v1_listener
    swl_ext_foreign_toplevel_list_v1_listener_impl = {
        .toplevel = swl_ext_foreign_toplevel_list_v1_handle_toplevel,
        .finished = swl_ext_foreign_toplevel_list_v1_handle_finished,
    };

int swl_ext_foreign_toplevel_list_v1_add_listener(
    struct ext_foreign_toplevel_list_v1 *list,
    const struct swl_ext_foreign_toplevel_list_v1_listener_callbacks *callbacks)
{
    return ext_foreign_toplevel_list_v1_add_listener(
        list,
        &swl_ext_foreign_toplevel_list_v1_listener_impl,
        (void *)callbacks);
}

static void swl_ext_foreign_toplevel_handle_v1_handle_closed(
    void *data,
    struct ext_foreign_toplevel_handle_v1 *handle)
{
    const struct swl_ext_foreign_toplevel_handle_v1_listener_callbacks *cb =
        data;
    if (cb != NULL && cb->closed != NULL) {
        cb->closed(cb->data, handle);
    }
}

static void swl_ext_foreign_toplevel_handle_v1_handle_done(
    void *data,
    struct ext_foreign_toplevel_handle_v1 *handle)
{
    const struct swl_ext_foreign_toplevel_handle_v1_listener_callbacks *cb =
        data;
    if (cb != NULL && cb->done != NULL) {
        cb->done(cb->data, handle);
    }
}

static void swl_ext_foreign_toplevel_handle_v1_handle_title(
    void *data,
    struct ext_foreign_toplevel_handle_v1 *handle,
    const char *title)
{
    const struct swl_ext_foreign_toplevel_handle_v1_listener_callbacks *cb =
        data;
    if (cb != NULL && cb->title != NULL) {
        cb->title(cb->data, handle, title);
    }
}

static void swl_ext_foreign_toplevel_handle_v1_handle_app_id(
    void *data,
    struct ext_foreign_toplevel_handle_v1 *handle,
    const char *app_id)
{
    const struct swl_ext_foreign_toplevel_handle_v1_listener_callbacks *cb =
        data;
    if (cb != NULL && cb->app_id != NULL) {
        cb->app_id(cb->data, handle, app_id);
    }
}

static void swl_ext_foreign_toplevel_handle_v1_handle_identifier(
    void *data,
    struct ext_foreign_toplevel_handle_v1 *handle,
    const char *identifier)
{
    const struct swl_ext_foreign_toplevel_handle_v1_listener_callbacks *cb =
        data;
    if (cb != NULL && cb->identifier != NULL) {
        cb->identifier(cb->data, handle, identifier);
    }
}

static const struct ext_foreign_toplevel_handle_v1_listener
    swl_ext_foreign_toplevel_handle_v1_listener_impl = {
        .closed = swl_ext_foreign_toplevel_handle_v1_handle_closed,
        .done = swl_ext_foreign_toplevel_handle_v1_handle_done,
        .title = swl_ext_foreign_toplevel_handle_v1_handle_title,
        .app_id = swl_ext_foreign_toplevel_handle_v1_handle_app_id,
        .identifier = swl_ext_foreign_toplevel_handle_v1_handle_identifier,
    };

int swl_ext_foreign_toplevel_handle_v1_add_listener(
    struct ext_foreign_toplevel_handle_v1 *handle,
    const struct swl_ext_foreign_toplevel_handle_v1_listener_callbacks *callbacks)
{
    return ext_foreign_toplevel_handle_v1_add_listener(
        handle,
        &swl_ext_foreign_toplevel_handle_v1_listener_impl,
        (void *)callbacks);
}
