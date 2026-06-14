#include "wayland-client-kit-shims.h"
#include "generated/staging/xdg-session-management/xdg-session-management-v1-client-protocol.h"
#include "generated/stable/xdg-shell/xdg-shell-client-protocol.h"

struct xdg_session_v1 *swl_xdg_session_manager_v1_get_session(
    struct xdg_session_manager_v1 *manager,
    uint32_t reason,
    const char *session_id)
{
    return xdg_session_manager_v1_get_session(manager, reason, session_id);
}

void swl_xdg_session_manager_v1_destroy(struct xdg_session_manager_v1 *manager)
{
    xdg_session_manager_v1_destroy(manager);
}

struct xdg_toplevel_session_v1 *swl_xdg_session_v1_add_toplevel(
    struct xdg_session_v1 *session,
    struct xdg_toplevel *toplevel,
    const char *name)
{
    return xdg_session_v1_add_toplevel(session, toplevel, name);
}

struct xdg_toplevel_session_v1 *swl_xdg_session_v1_restore_toplevel(
    struct xdg_session_v1 *session,
    struct xdg_toplevel *toplevel,
    const char *name)
{
    return xdg_session_v1_restore_toplevel(session, toplevel, name);
}

void swl_xdg_session_v1_remove_toplevel(
    struct xdg_session_v1 *session,
    const char *name)
{
    xdg_session_v1_remove_toplevel(session, name);
}

void swl_xdg_session_v1_destroy(struct xdg_session_v1 *session)
{
    xdg_session_v1_destroy(session);
}

void swl_xdg_session_v1_remove(struct xdg_session_v1 *session)
{
    xdg_session_v1_remove(session);
}

void swl_xdg_toplevel_session_v1_rename(
    struct xdg_toplevel_session_v1 *toplevel_session,
    const char *name)
{
    xdg_toplevel_session_v1_rename(toplevel_session, name);
}

void swl_xdg_toplevel_session_v1_destroy(
    struct xdg_toplevel_session_v1 *toplevel_session)
{
    xdg_toplevel_session_v1_destroy(toplevel_session);
}

