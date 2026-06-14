#include "wayland-client-kit-shims.h"
#include "generated/staging/xdg-session-management/xdg-session-management-v1-client-protocol.h"

static void swl_session_handle_created(
    void *data,
    struct xdg_session_v1 *session,
    const char *session_id)
{
    const struct swl_xdg_session_v1_listener_callbacks *cb = data;
    if (cb && cb->created)
        cb->created(cb->data, session, session_id);
}

static void swl_session_handle_restored(
    void *data,
    struct xdg_session_v1 *session)
{
    const struct swl_xdg_session_v1_listener_callbacks *cb = data;
    if (cb && cb->restored)
        cb->restored(cb->data, session);
}

static void swl_session_handle_replaced(
    void *data,
    struct xdg_session_v1 *session)
{
    const struct swl_xdg_session_v1_listener_callbacks *cb = data;
    if (cb && cb->replaced)
        cb->replaced(cb->data, session);
}

static const struct xdg_session_v1_listener swl_session_listener_impl = {
    .created  = swl_session_handle_created,
    .restored = swl_session_handle_restored,
    .replaced = swl_session_handle_replaced,
};

int swl_xdg_session_v1_add_listener(
    struct xdg_session_v1 *session,
    const struct swl_xdg_session_v1_listener_callbacks *callbacks)
{
    return xdg_session_v1_add_listener(session, &swl_session_listener_impl, (void *)callbacks);
}

static void swl_toplevel_session_handle_restored(
    void *data,
    struct xdg_toplevel_session_v1 *toplevel_session)
{
    const struct swl_xdg_toplevel_session_v1_listener_callbacks *cb = data;
    if (cb && cb->restored)
        cb->restored(cb->data, toplevel_session);
}

static const struct xdg_toplevel_session_v1_listener swl_toplevel_session_listener_impl = {
    .restored = swl_toplevel_session_handle_restored,
};

int swl_xdg_toplevel_session_v1_add_listener(
    struct xdg_toplevel_session_v1 *toplevel_session,
    const struct swl_xdg_toplevel_session_v1_listener_callbacks *callbacks)
{
    return xdg_toplevel_session_v1_add_listener(
        toplevel_session,
        &swl_toplevel_session_listener_impl,
        (void *)callbacks);
}

