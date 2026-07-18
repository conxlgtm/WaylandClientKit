#include "wayland-client-kit-shims.h"
#include "generated/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1-client-protocol.h"
#include "generated/staging/xdg-system-bell/xdg-system-bell-v1-client-protocol.h"
#include "generated/staging/xdg-dialog/xdg-dialog-v1-client-protocol.h"
#include "generated/staging/xdg-toplevel-drag/xdg-toplevel-drag-v1-client-protocol.h"
#include "generated/staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1-client-protocol.h"
#include "generated/legacy-unstable/idle-inhibit/idle-inhibit-unstable-v1-client-protocol.h"
#include <stddef.h>

#ifdef SWL_ENABLE_TESTING
static char swl_test_desktop_request_text[256];
static struct swl_test_desktop_request_record swl_test_desktop_request_latest;
static struct swl_test_desktop_destroy_record swl_test_desktop_destroy_latest;
static int swl_test_desktop_request_forwards_requests;

static struct xdg_toplevel_icon_v1 *swl_xdg_toplevel_icon_manager_v1_create_icon_default(
    struct xdg_toplevel_icon_manager_v1 *manager)
{
    return xdg_toplevel_icon_manager_v1_create_icon(manager);
}

static void swl_xdg_toplevel_icon_manager_v1_set_icon_default(
    struct xdg_toplevel_icon_manager_v1 *manager,
    struct xdg_toplevel *toplevel,
    struct xdg_toplevel_icon_v1 *icon)
{
    xdg_toplevel_icon_manager_v1_set_icon(manager, toplevel, icon);
}

static void swl_xdg_toplevel_icon_v1_set_name_default(
    struct xdg_toplevel_icon_v1 *icon,
    const char *name)
{
    xdg_toplevel_icon_v1_set_name(icon, name);
}

static void swl_xdg_toplevel_icon_v1_add_buffer_default(
    struct xdg_toplevel_icon_v1 *icon,
    struct wl_buffer *buffer,
    int32_t scale)
{
    xdg_toplevel_icon_v1_add_buffer(icon, buffer, scale);
}

static struct zwp_idle_inhibitor_v1 *swl_zwp_idle_inhibit_manager_v1_create_inhibitor_default(
    struct zwp_idle_inhibit_manager_v1 *manager,
    struct wl_surface *surface)
{
    return zwp_idle_inhibit_manager_v1_create_inhibitor(manager, surface);
}

static void swl_xdg_system_bell_v1_ring_default(
    struct xdg_system_bell_v1 *bell,
    struct wl_surface *surface)
{
    xdg_system_bell_v1_ring(bell, surface);
}

static struct xdg_dialog_v1 *swl_xdg_wm_dialog_v1_get_xdg_dialog_default(
    struct xdg_wm_dialog_v1 *manager,
    struct xdg_toplevel *toplevel)
{
    return xdg_wm_dialog_v1_get_xdg_dialog(manager, toplevel);
}

static void swl_xdg_dialog_v1_set_modal_default(struct xdg_dialog_v1 *dialog)
{
    xdg_dialog_v1_set_modal(dialog);
}

static void swl_xdg_dialog_v1_unset_modal_default(struct xdg_dialog_v1 *dialog)
{
    xdg_dialog_v1_unset_modal(dialog);
}

static struct xdg_toplevel_drag_v1 *
swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag_default(
    struct xdg_toplevel_drag_manager_v1 *manager,
    struct wl_data_source *source)
{
    return xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag(manager, source);
}

static void swl_xdg_toplevel_drag_v1_attach_default(
    struct xdg_toplevel_drag_v1 *drag,
    struct xdg_toplevel *toplevel,
    int32_t x_offset,
    int32_t y_offset)
{
    xdg_toplevel_drag_v1_attach(drag, toplevel, x_offset, y_offset);
}

static void swl_ext_foreign_toplevel_list_v1_stop_default(
    struct ext_foreign_toplevel_list_v1 *list)
{
    ext_foreign_toplevel_list_v1_stop(list);
}

static void swl_xdg_toplevel_icon_manager_v1_destroy_default(
    struct xdg_toplevel_icon_manager_v1 *manager)
{
    xdg_toplevel_icon_manager_v1_destroy(manager);
}

static void swl_xdg_toplevel_icon_v1_destroy_default(
    struct xdg_toplevel_icon_v1 *icon)
{
    xdg_toplevel_icon_v1_destroy(icon);
}

static void swl_zwp_idle_inhibit_manager_v1_destroy_default(
    struct zwp_idle_inhibit_manager_v1 *manager)
{
    zwp_idle_inhibit_manager_v1_destroy(manager);
}

static void swl_zwp_idle_inhibitor_v1_destroy_default(
    struct zwp_idle_inhibitor_v1 *inhibitor)
{
    zwp_idle_inhibitor_v1_destroy(inhibitor);
}

static void swl_xdg_system_bell_v1_destroy_default(struct xdg_system_bell_v1 *bell)
{
    xdg_system_bell_v1_destroy(bell);
}

static void swl_xdg_wm_dialog_v1_destroy_default(
    struct xdg_wm_dialog_v1 *manager)
{
    xdg_wm_dialog_v1_destroy(manager);
}

static void swl_xdg_dialog_v1_destroy_default(struct xdg_dialog_v1 *dialog)
{
    xdg_dialog_v1_destroy(dialog);
}

static void swl_xdg_toplevel_drag_manager_v1_destroy_default(
    struct xdg_toplevel_drag_manager_v1 *manager)
{
    xdg_toplevel_drag_manager_v1_destroy(manager);
}

static void swl_xdg_toplevel_drag_v1_destroy_default(
    struct xdg_toplevel_drag_v1 *drag)
{
    xdg_toplevel_drag_v1_destroy(drag);
}

static void swl_ext_foreign_toplevel_list_v1_destroy_default(
    struct ext_foreign_toplevel_list_v1 *list)
{
    ext_foreign_toplevel_list_v1_destroy(list);
}

static void swl_ext_foreign_toplevel_handle_v1_destroy_default(
    struct ext_foreign_toplevel_handle_v1 *handle)
{
    ext_foreign_toplevel_handle_v1_destroy(handle);
}

static struct xdg_toplevel_icon_v1 *(*swl_xdg_toplevel_icon_manager_v1_create_icon_impl)(
    struct xdg_toplevel_icon_manager_v1 *manager) =
    swl_xdg_toplevel_icon_manager_v1_create_icon_default;
static void (*swl_xdg_toplevel_icon_manager_v1_set_icon_impl)(
    struct xdg_toplevel_icon_manager_v1 *manager,
    struct xdg_toplevel *toplevel,
    struct xdg_toplevel_icon_v1 *icon) =
    swl_xdg_toplevel_icon_manager_v1_set_icon_default;
static void (*swl_xdg_toplevel_icon_v1_set_name_impl)(
    struct xdg_toplevel_icon_v1 *icon,
    const char *name) = swl_xdg_toplevel_icon_v1_set_name_default;
static void (*swl_xdg_toplevel_icon_v1_add_buffer_impl)(
    struct xdg_toplevel_icon_v1 *icon,
    struct wl_buffer *buffer,
    int32_t scale) = swl_xdg_toplevel_icon_v1_add_buffer_default;
static struct zwp_idle_inhibitor_v1 *(*swl_zwp_idle_inhibit_manager_v1_create_inhibitor_impl)(
    struct zwp_idle_inhibit_manager_v1 *manager,
    struct wl_surface *surface) =
    swl_zwp_idle_inhibit_manager_v1_create_inhibitor_default;
static void (*swl_xdg_system_bell_v1_ring_impl)(
    struct xdg_system_bell_v1 *bell,
    struct wl_surface *surface) = swl_xdg_system_bell_v1_ring_default;
static struct xdg_dialog_v1 *(*swl_xdg_wm_dialog_v1_get_xdg_dialog_impl)(
    struct xdg_wm_dialog_v1 *manager,
    struct xdg_toplevel *toplevel) =
    swl_xdg_wm_dialog_v1_get_xdg_dialog_default;
static void (*swl_xdg_dialog_v1_set_modal_impl)(
    struct xdg_dialog_v1 *dialog) = swl_xdg_dialog_v1_set_modal_default;
static void (*swl_xdg_dialog_v1_unset_modal_impl)(
    struct xdg_dialog_v1 *dialog) = swl_xdg_dialog_v1_unset_modal_default;
static struct xdg_toplevel_drag_v1 *(
    *swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag_impl)(
    struct xdg_toplevel_drag_manager_v1 *manager,
    struct wl_data_source *source) =
    swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag_default;
static void (*swl_xdg_toplevel_drag_v1_attach_impl)(
    struct xdg_toplevel_drag_v1 *drag,
    struct xdg_toplevel *toplevel,
    int32_t x_offset,
    int32_t y_offset) = swl_xdg_toplevel_drag_v1_attach_default;
static void (*swl_ext_foreign_toplevel_list_v1_stop_impl)(
    struct ext_foreign_toplevel_list_v1 *list) =
    swl_ext_foreign_toplevel_list_v1_stop_default;
static void (*swl_xdg_toplevel_icon_manager_v1_destroy_impl)(
    struct xdg_toplevel_icon_manager_v1 *manager) =
    swl_xdg_toplevel_icon_manager_v1_destroy_default;
static void (*swl_xdg_toplevel_icon_v1_destroy_impl)(
    struct xdg_toplevel_icon_v1 *icon) = swl_xdg_toplevel_icon_v1_destroy_default;
static void (*swl_zwp_idle_inhibit_manager_v1_destroy_impl)(
    struct zwp_idle_inhibit_manager_v1 *manager) =
    swl_zwp_idle_inhibit_manager_v1_destroy_default;
static void (*swl_zwp_idle_inhibitor_v1_destroy_impl)(
    struct zwp_idle_inhibitor_v1 *inhibitor) =
    swl_zwp_idle_inhibitor_v1_destroy_default;
static void (*swl_xdg_system_bell_v1_destroy_impl)(
    struct xdg_system_bell_v1 *bell) = swl_xdg_system_bell_v1_destroy_default;
static void (*swl_xdg_wm_dialog_v1_destroy_impl)(
    struct xdg_wm_dialog_v1 *manager) = swl_xdg_wm_dialog_v1_destroy_default;
static void (*swl_xdg_dialog_v1_destroy_impl)(
    struct xdg_dialog_v1 *dialog) = swl_xdg_dialog_v1_destroy_default;
static void (*swl_xdg_toplevel_drag_manager_v1_destroy_impl)(
    struct xdg_toplevel_drag_manager_v1 *manager) =
    swl_xdg_toplevel_drag_manager_v1_destroy_default;
static void (*swl_xdg_toplevel_drag_v1_destroy_impl)(
    struct xdg_toplevel_drag_v1 *drag) =
    swl_xdg_toplevel_drag_v1_destroy_default;
static void (*swl_ext_foreign_toplevel_list_v1_destroy_impl)(
    struct ext_foreign_toplevel_list_v1 *list) =
    swl_ext_foreign_toplevel_list_v1_destroy_default;
static void (*swl_ext_foreign_toplevel_handle_v1_destroy_impl)(
    struct ext_foreign_toplevel_handle_v1 *handle) =
    swl_ext_foreign_toplevel_handle_v1_destroy_default;

static void swl_test_copy_desktop_request_text(const char *text)
{
    if (text == NULL) {
        swl_test_desktop_request_text[0] = '\0';
        swl_test_desktop_request_latest.text = swl_test_desktop_request_text;
        return;
    }

    size_t index = 0;
    while (index < sizeof(swl_test_desktop_request_text) - 1
        && text[index] != '\0') {
        swl_test_desktop_request_text[index] = text[index];
        index += 1;
    }
    swl_test_desktop_request_text[index] = '\0';
    swl_test_desktop_request_latest.text = swl_test_desktop_request_text;
}

static void swl_test_record_desktop_request(
    enum swl_test_desktop_request_kind kind,
    void *object)
{
    swl_test_desktop_request_latest.call_count += 1;
    swl_test_desktop_request_latest.kind = kind;
    swl_test_desktop_request_latest.object = object;
}

static struct xdg_toplevel_icon_v1 *swl_test_toplevel_icon_create_icon_record(
    struct xdg_toplevel_icon_manager_v1 *manager)
{
    swl_test_record_desktop_request(
        SWL_TEST_DESKTOP_TOPLEVEL_ICON_CREATE_ICON, manager);
    if (swl_test_desktop_request_forwards_requests) {
        swl_test_desktop_request_latest.icon =
            swl_xdg_toplevel_icon_manager_v1_create_icon_default(manager);
        return swl_test_desktop_request_latest.icon;
    }
    swl_test_desktop_request_latest.icon =
        (struct xdg_toplevel_icon_v1 *)0xD101;
    return swl_test_desktop_request_latest.icon;
}

static void swl_test_toplevel_icon_set_icon_record(
    struct xdg_toplevel_icon_manager_v1 *manager,
    struct xdg_toplevel *toplevel,
    struct xdg_toplevel_icon_v1 *icon)
{
    swl_test_record_desktop_request(
        SWL_TEST_DESKTOP_TOPLEVEL_ICON_SET_ICON, manager);
    swl_test_desktop_request_latest.toplevel = toplevel;
    swl_test_desktop_request_latest.icon = icon;
    if (swl_test_desktop_request_forwards_requests) {
        swl_xdg_toplevel_icon_manager_v1_set_icon_default(
            manager, toplevel, icon);
    }
}

static void swl_test_toplevel_icon_set_name_record(
    struct xdg_toplevel_icon_v1 *icon,
    const char *name)
{
    swl_test_record_desktop_request(
        SWL_TEST_DESKTOP_TOPLEVEL_ICON_SET_NAME, icon);
    swl_test_copy_desktop_request_text(name);
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_toplevel_icon_v1_set_name_default(icon, name);
}

static void swl_test_toplevel_icon_add_buffer_record(
    struct xdg_toplevel_icon_v1 *icon,
    struct wl_buffer *buffer,
    int32_t scale)
{
    swl_test_record_desktop_request(
        SWL_TEST_DESKTOP_TOPLEVEL_ICON_ADD_BUFFER, icon);
    swl_test_desktop_request_latest.buffer = buffer;
    swl_test_desktop_request_latest.scale = scale;
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_toplevel_icon_v1_add_buffer_default(icon, buffer, scale);
}

static struct zwp_idle_inhibitor_v1 *swl_test_idle_inhibit_create_inhibitor_record(
    struct zwp_idle_inhibit_manager_v1 *manager,
    struct wl_surface *surface)
{
    swl_test_record_desktop_request(
        SWL_TEST_DESKTOP_IDLE_INHIBIT_CREATE_INHIBITOR, manager);
    swl_test_desktop_request_latest.surface = surface;
    if (swl_test_desktop_request_forwards_requests) {
        swl_test_desktop_request_latest.inhibitor =
            swl_zwp_idle_inhibit_manager_v1_create_inhibitor_default(
                manager, surface);
        return swl_test_desktop_request_latest.inhibitor;
    }
    swl_test_desktop_request_latest.inhibitor =
        (struct zwp_idle_inhibitor_v1 *)0xD202;
    return swl_test_desktop_request_latest.inhibitor;
}

static void swl_test_system_bell_ring_record(
    struct xdg_system_bell_v1 *bell,
    struct wl_surface *surface)
{
    swl_test_record_desktop_request(SWL_TEST_DESKTOP_SYSTEM_BELL_RING, bell);
    swl_test_desktop_request_latest.surface = surface;
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_system_bell_v1_ring_default(bell, surface);
}

static struct xdg_dialog_v1 *swl_test_dialog_get_record(
    struct xdg_wm_dialog_v1 *manager,
    struct xdg_toplevel *toplevel)
{
    swl_test_record_desktop_request(SWL_TEST_DESKTOP_DIALOG_GET, manager);
    swl_test_desktop_request_latest.toplevel = toplevel;
    if (swl_test_desktop_request_forwards_requests) {
        swl_test_desktop_request_latest.dialog =
            swl_xdg_wm_dialog_v1_get_xdg_dialog_default(manager, toplevel);
        return swl_test_desktop_request_latest.dialog;
    }
    swl_test_desktop_request_latest.dialog = (struct xdg_dialog_v1 *)0xD301;
    return swl_test_desktop_request_latest.dialog;
}

static void swl_test_dialog_set_modal_record(struct xdg_dialog_v1 *dialog)
{
    swl_test_record_desktop_request(SWL_TEST_DESKTOP_DIALOG_SET_MODAL, dialog);
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_dialog_v1_set_modal_default(dialog);
}

static void swl_test_dialog_unset_modal_record(struct xdg_dialog_v1 *dialog)
{
    swl_test_record_desktop_request(SWL_TEST_DESKTOP_DIALOG_UNSET_MODAL, dialog);
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_dialog_v1_unset_modal_default(dialog);
}

static struct xdg_toplevel_drag_v1 *swl_test_toplevel_drag_get_record(
    struct xdg_toplevel_drag_manager_v1 *manager,
    struct wl_data_source *source)
{
    swl_test_record_desktop_request(SWL_TEST_DESKTOP_TOPLEVEL_DRAG_GET, manager);
    swl_test_desktop_request_latest.data_source = source;
    if (swl_test_desktop_request_forwards_requests) {
        swl_test_desktop_request_latest.drag =
            swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag_default(
                manager, source);
        return swl_test_desktop_request_latest.drag;
    }
    swl_test_desktop_request_latest.drag =
        (struct xdg_toplevel_drag_v1 *)0xD401;
    return swl_test_desktop_request_latest.drag;
}

static void swl_test_toplevel_drag_attach_record(
    struct xdg_toplevel_drag_v1 *drag,
    struct xdg_toplevel *toplevel,
    int32_t x_offset,
    int32_t y_offset)
{
    swl_test_record_desktop_request(SWL_TEST_DESKTOP_TOPLEVEL_DRAG_ATTACH, drag);
    swl_test_desktop_request_latest.toplevel = toplevel;
    swl_test_desktop_request_latest.x = x_offset;
    swl_test_desktop_request_latest.y = y_offset;
    if (swl_test_desktop_request_forwards_requests) {
        swl_xdg_toplevel_drag_v1_attach_default(
            drag, toplevel, x_offset, y_offset);
    }
}

static void swl_test_foreign_toplevel_list_stop_record(
    struct ext_foreign_toplevel_list_v1 *list)
{
    swl_test_record_desktop_request(
        SWL_TEST_DESKTOP_FOREIGN_TOPLEVEL_LIST_STOP, list);
    if (swl_test_desktop_request_forwards_requests)
        swl_ext_foreign_toplevel_list_v1_stop_default(list);
}

static void swl_test_note_desktop_destroy(
    enum swl_test_desktop_destroy_kind kind,
    void *object)
{
    swl_test_desktop_destroy_latest.call_count += 1;
    swl_test_desktop_destroy_latest.kind = kind;
    swl_test_desktop_destroy_latest.object = object;
}

static void swl_test_toplevel_icon_manager_destroy_record(
    struct xdg_toplevel_icon_manager_v1 *manager)
{
    swl_test_note_desktop_destroy(
        SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_ICON_MANAGER, manager);
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_toplevel_icon_manager_v1_destroy_default(manager);
}

static void swl_test_toplevel_icon_destroy_record(
    struct xdg_toplevel_icon_v1 *icon)
{
    swl_test_note_desktop_destroy(SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_ICON, icon);
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_toplevel_icon_v1_destroy_default(icon);
}

static void swl_test_idle_inhibit_manager_destroy_record(
    struct zwp_idle_inhibit_manager_v1 *manager)
{
    swl_test_note_desktop_destroy(
        SWL_TEST_DESKTOP_DESTROY_IDLE_INHIBIT_MANAGER, manager);
    if (swl_test_desktop_request_forwards_requests)
        swl_zwp_idle_inhibit_manager_v1_destroy_default(manager);
}

static void swl_test_idle_inhibitor_destroy_record(
    struct zwp_idle_inhibitor_v1 *inhibitor)
{
    swl_test_note_desktop_destroy(
        SWL_TEST_DESKTOP_DESTROY_IDLE_INHIBITOR, inhibitor);
    if (swl_test_desktop_request_forwards_requests)
        swl_zwp_idle_inhibitor_v1_destroy_default(inhibitor);
}

static void swl_test_system_bell_destroy_record(struct xdg_system_bell_v1 *bell)
{
    swl_test_note_desktop_destroy(SWL_TEST_DESKTOP_DESTROY_SYSTEM_BELL, bell);
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_system_bell_v1_destroy_default(bell);
}

static void swl_test_dialog_manager_destroy_record(
    struct xdg_wm_dialog_v1 *manager)
{
    swl_test_note_desktop_destroy(
        SWL_TEST_DESKTOP_DESTROY_DIALOG_MANAGER, manager);
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_wm_dialog_v1_destroy_default(manager);
}

static void swl_test_dialog_destroy_record(struct xdg_dialog_v1 *dialog)
{
    swl_test_note_desktop_destroy(SWL_TEST_DESKTOP_DESTROY_DIALOG, dialog);
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_dialog_v1_destroy_default(dialog);
}

static void swl_test_toplevel_drag_manager_destroy_record(
    struct xdg_toplevel_drag_manager_v1 *manager)
{
    swl_test_note_desktop_destroy(
        SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_DRAG_MANAGER, manager);
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_toplevel_drag_manager_v1_destroy_default(manager);
}

static void swl_test_toplevel_drag_destroy_record(
    struct xdg_toplevel_drag_v1 *drag)
{
    swl_test_note_desktop_destroy(SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_DRAG, drag);
    if (swl_test_desktop_request_forwards_requests)
        swl_xdg_toplevel_drag_v1_destroy_default(drag);
}

static void swl_test_foreign_toplevel_list_destroy_record(
    struct ext_foreign_toplevel_list_v1 *list)
{
    swl_test_note_desktop_destroy(
        SWL_TEST_DESKTOP_DESTROY_FOREIGN_TOPLEVEL_LIST, list);
    if (swl_test_desktop_request_forwards_requests)
        swl_ext_foreign_toplevel_list_v1_destroy_default(list);
}

static void swl_test_foreign_toplevel_handle_destroy_record(
    struct ext_foreign_toplevel_handle_v1 *handle)
{
    swl_test_note_desktop_destroy(
        SWL_TEST_DESKTOP_DESTROY_FOREIGN_TOPLEVEL_HANDLE, handle);
    if (swl_test_desktop_request_forwards_requests)
        swl_ext_foreign_toplevel_handle_v1_destroy_default(handle);
}
#else
#define swl_xdg_toplevel_icon_manager_v1_create_icon_impl \
    xdg_toplevel_icon_manager_v1_create_icon
#define swl_xdg_toplevel_icon_manager_v1_set_icon_impl \
    xdg_toplevel_icon_manager_v1_set_icon
#define swl_xdg_toplevel_icon_v1_set_name_impl xdg_toplevel_icon_v1_set_name
#define swl_xdg_toplevel_icon_v1_add_buffer_impl xdg_toplevel_icon_v1_add_buffer
#define swl_zwp_idle_inhibit_manager_v1_create_inhibitor_impl \
    zwp_idle_inhibit_manager_v1_create_inhibitor
#define swl_xdg_system_bell_v1_ring_impl xdg_system_bell_v1_ring
#define swl_xdg_wm_dialog_v1_get_xdg_dialog_impl \
    xdg_wm_dialog_v1_get_xdg_dialog
#define swl_xdg_dialog_v1_set_modal_impl xdg_dialog_v1_set_modal
#define swl_xdg_dialog_v1_unset_modal_impl xdg_dialog_v1_unset_modal
#define swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag_impl \
    xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag
#define swl_xdg_toplevel_drag_v1_attach_impl xdg_toplevel_drag_v1_attach
#define swl_ext_foreign_toplevel_list_v1_stop_impl \
    ext_foreign_toplevel_list_v1_stop
#define swl_xdg_toplevel_icon_manager_v1_destroy_impl \
    xdg_toplevel_icon_manager_v1_destroy
#define swl_xdg_toplevel_icon_v1_destroy_impl xdg_toplevel_icon_v1_destroy
#define swl_zwp_idle_inhibit_manager_v1_destroy_impl \
    zwp_idle_inhibit_manager_v1_destroy
#define swl_zwp_idle_inhibitor_v1_destroy_impl zwp_idle_inhibitor_v1_destroy
#define swl_xdg_system_bell_v1_destroy_impl xdg_system_bell_v1_destroy
#define swl_xdg_wm_dialog_v1_destroy_impl xdg_wm_dialog_v1_destroy
#define swl_xdg_dialog_v1_destroy_impl xdg_dialog_v1_destroy
#define swl_xdg_toplevel_drag_manager_v1_destroy_impl \
    xdg_toplevel_drag_manager_v1_destroy
#define swl_xdg_toplevel_drag_v1_destroy_impl xdg_toplevel_drag_v1_destroy
#define swl_ext_foreign_toplevel_list_v1_destroy_impl \
    ext_foreign_toplevel_list_v1_destroy
#define swl_ext_foreign_toplevel_handle_v1_destroy_impl \
    ext_foreign_toplevel_handle_v1_destroy
#endif

struct xdg_toplevel_icon_v1 *
swl_xdg_toplevel_icon_manager_v1_create_icon(
    struct xdg_toplevel_icon_manager_v1 *manager)
{
    return swl_xdg_toplevel_icon_manager_v1_create_icon_impl(manager);
}

void swl_xdg_toplevel_icon_manager_v1_set_icon(
    struct xdg_toplevel_icon_manager_v1 *manager,
    struct xdg_toplevel *toplevel,
    struct xdg_toplevel_icon_v1 *icon)
{
    swl_xdg_toplevel_icon_manager_v1_set_icon_impl(manager, toplevel, icon);
}

void swl_xdg_toplevel_icon_v1_set_name(
    struct xdg_toplevel_icon_v1 *icon,
    const char *name)
{
    swl_xdg_toplevel_icon_v1_set_name_impl(icon, name);
}

void swl_xdg_toplevel_icon_v1_add_buffer(
    struct xdg_toplevel_icon_v1 *icon,
    struct wl_buffer *buffer,
    int32_t scale)
{
    swl_xdg_toplevel_icon_v1_add_buffer_impl(icon, buffer, scale);
}

struct zwp_idle_inhibitor_v1 *
swl_zwp_idle_inhibit_manager_v1_create_inhibitor(
    struct zwp_idle_inhibit_manager_v1 *manager,
    struct wl_surface *surface)
{
    return swl_zwp_idle_inhibit_manager_v1_create_inhibitor_impl(manager, surface);
}

void swl_xdg_system_bell_v1_ring(
    struct xdg_system_bell_v1 *bell,
    struct wl_surface *surface)
{
    swl_xdg_system_bell_v1_ring_impl(bell, surface);
}

void swl_xdg_wm_dialog_v1_destroy(struct xdg_wm_dialog_v1 *manager)
{
    swl_xdg_wm_dialog_v1_destroy_impl(manager);
}

struct xdg_dialog_v1 *swl_xdg_wm_dialog_v1_get_xdg_dialog(
    struct xdg_wm_dialog_v1 *manager,
    struct xdg_toplevel *toplevel)
{
    return swl_xdg_wm_dialog_v1_get_xdg_dialog_impl(manager, toplevel);
}

void swl_xdg_dialog_v1_destroy(struct xdg_dialog_v1 *dialog)
{
    swl_xdg_dialog_v1_destroy_impl(dialog);
}

void swl_xdg_dialog_v1_set_modal(struct xdg_dialog_v1 *dialog)
{
    swl_xdg_dialog_v1_set_modal_impl(dialog);
}

void swl_xdg_dialog_v1_unset_modal(struct xdg_dialog_v1 *dialog)
{
    swl_xdg_dialog_v1_unset_modal_impl(dialog);
}

void swl_xdg_toplevel_drag_manager_v1_destroy(
    struct xdg_toplevel_drag_manager_v1 *manager)
{
    swl_xdg_toplevel_drag_manager_v1_destroy_impl(manager);
}

struct xdg_toplevel_drag_v1 *swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag(
    struct xdg_toplevel_drag_manager_v1 *manager,
    struct wl_data_source *source)
{
    return swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag_impl(
        manager, source);
}

void swl_xdg_toplevel_drag_v1_destroy(struct xdg_toplevel_drag_v1 *drag)
{
    swl_xdg_toplevel_drag_v1_destroy_impl(drag);
}

void swl_xdg_toplevel_drag_v1_attach(
    struct xdg_toplevel_drag_v1 *drag,
    struct xdg_toplevel *toplevel,
    int32_t x_offset,
    int32_t y_offset)
{
    swl_xdg_toplevel_drag_v1_attach_impl(drag, toplevel, x_offset, y_offset);
}

void swl_ext_foreign_toplevel_list_v1_stop(
    struct ext_foreign_toplevel_list_v1 *list)
{
    swl_ext_foreign_toplevel_list_v1_stop_impl(list);
}

void swl_ext_foreign_toplevel_list_v1_destroy(
    struct ext_foreign_toplevel_list_v1 *list)
{
    swl_ext_foreign_toplevel_list_v1_destroy_impl(list);
}

void swl_ext_foreign_toplevel_handle_v1_destroy(
    struct ext_foreign_toplevel_handle_v1 *handle)
{
    swl_ext_foreign_toplevel_handle_v1_destroy_impl(handle);
}

void swl_xdg_toplevel_icon_manager_v1_destroy(
    struct xdg_toplevel_icon_manager_v1 *manager)
{
    swl_xdg_toplevel_icon_manager_v1_destroy_impl(manager);
}

void swl_xdg_toplevel_icon_v1_destroy(struct xdg_toplevel_icon_v1 *icon)
{
    swl_xdg_toplevel_icon_v1_destroy_impl(icon);
}

void swl_zwp_idle_inhibit_manager_v1_destroy(
    struct zwp_idle_inhibit_manager_v1 *manager)
{
    swl_zwp_idle_inhibit_manager_v1_destroy_impl(manager);
}

void swl_zwp_idle_inhibitor_v1_destroy(struct zwp_idle_inhibitor_v1 *inhibitor)
{
    swl_zwp_idle_inhibitor_v1_destroy_impl(inhibitor);
}

void swl_xdg_system_bell_v1_destroy(struct xdg_system_bell_v1 *bell)
{
    swl_xdg_system_bell_v1_destroy_impl(bell);
}

#ifdef SWL_ENABLE_TESTING
static void swl_test_desktop_request_recording_start(int forwards_requests)
{
    swl_test_desktop_request_text[0] = '\0';
    swl_test_desktop_request_latest =
        (struct swl_test_desktop_request_record){0};
    swl_test_desktop_destroy_latest =
        (struct swl_test_desktop_destroy_record){0};
    swl_test_desktop_request_forwards_requests = forwards_requests;
    swl_xdg_toplevel_icon_manager_v1_create_icon_impl =
        swl_test_toplevel_icon_create_icon_record;
    swl_xdg_toplevel_icon_manager_v1_set_icon_impl =
        swl_test_toplevel_icon_set_icon_record;
    swl_xdg_toplevel_icon_v1_set_name_impl =
        swl_test_toplevel_icon_set_name_record;
    swl_xdg_toplevel_icon_v1_add_buffer_impl =
        swl_test_toplevel_icon_add_buffer_record;
    swl_zwp_idle_inhibit_manager_v1_create_inhibitor_impl =
        swl_test_idle_inhibit_create_inhibitor_record;
    swl_xdg_system_bell_v1_ring_impl = swl_test_system_bell_ring_record;
    swl_xdg_wm_dialog_v1_get_xdg_dialog_impl = swl_test_dialog_get_record;
    swl_xdg_dialog_v1_set_modal_impl = swl_test_dialog_set_modal_record;
    swl_xdg_dialog_v1_unset_modal_impl = swl_test_dialog_unset_modal_record;
    swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag_impl =
        swl_test_toplevel_drag_get_record;
    swl_xdg_toplevel_drag_v1_attach_impl =
        swl_test_toplevel_drag_attach_record;
    swl_ext_foreign_toplevel_list_v1_stop_impl =
        swl_test_foreign_toplevel_list_stop_record;
    swl_xdg_toplevel_icon_manager_v1_destroy_impl =
        swl_test_toplevel_icon_manager_destroy_record;
    swl_xdg_toplevel_icon_v1_destroy_impl =
        swl_test_toplevel_icon_destroy_record;
    swl_zwp_idle_inhibit_manager_v1_destroy_impl =
        swl_test_idle_inhibit_manager_destroy_record;
    swl_zwp_idle_inhibitor_v1_destroy_impl =
        swl_test_idle_inhibitor_destroy_record;
    swl_xdg_system_bell_v1_destroy_impl = swl_test_system_bell_destroy_record;
    swl_xdg_wm_dialog_v1_destroy_impl =
        swl_test_dialog_manager_destroy_record;
    swl_xdg_dialog_v1_destroy_impl = swl_test_dialog_destroy_record;
    swl_xdg_toplevel_drag_manager_v1_destroy_impl =
        swl_test_toplevel_drag_manager_destroy_record;
    swl_xdg_toplevel_drag_v1_destroy_impl =
        swl_test_toplevel_drag_destroy_record;
    swl_ext_foreign_toplevel_list_v1_destroy_impl =
        swl_test_foreign_toplevel_list_destroy_record;
    swl_ext_foreign_toplevel_handle_v1_destroy_impl =
        swl_test_foreign_toplevel_handle_destroy_record;
}

void swl_test_desktop_request_recording_begin(void)
{
    swl_test_desktop_request_recording_start(0);
}

void swl_test_desktop_request_recording_begin_forwarding(void)
{
    swl_test_desktop_request_recording_start(1);
}

void swl_test_desktop_request_recording_end(void)
{
    swl_test_desktop_request_forwards_requests = 0;
    swl_xdg_toplevel_icon_manager_v1_create_icon_impl =
        swl_xdg_toplevel_icon_manager_v1_create_icon_default;
    swl_xdg_toplevel_icon_manager_v1_set_icon_impl =
        swl_xdg_toplevel_icon_manager_v1_set_icon_default;
    swl_xdg_toplevel_icon_v1_set_name_impl =
        swl_xdg_toplevel_icon_v1_set_name_default;
    swl_xdg_toplevel_icon_v1_add_buffer_impl =
        swl_xdg_toplevel_icon_v1_add_buffer_default;
    swl_zwp_idle_inhibit_manager_v1_create_inhibitor_impl =
        swl_zwp_idle_inhibit_manager_v1_create_inhibitor_default;
    swl_xdg_system_bell_v1_ring_impl = swl_xdg_system_bell_v1_ring_default;
    swl_xdg_wm_dialog_v1_get_xdg_dialog_impl =
        swl_xdg_wm_dialog_v1_get_xdg_dialog_default;
    swl_xdg_dialog_v1_set_modal_impl = swl_xdg_dialog_v1_set_modal_default;
    swl_xdg_dialog_v1_unset_modal_impl =
        swl_xdg_dialog_v1_unset_modal_default;
    swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag_impl =
        swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag_default;
    swl_xdg_toplevel_drag_v1_attach_impl =
        swl_xdg_toplevel_drag_v1_attach_default;
    swl_ext_foreign_toplevel_list_v1_stop_impl =
        swl_ext_foreign_toplevel_list_v1_stop_default;
    swl_xdg_toplevel_icon_manager_v1_destroy_impl =
        swl_xdg_toplevel_icon_manager_v1_destroy_default;
    swl_xdg_toplevel_icon_v1_destroy_impl =
        swl_xdg_toplevel_icon_v1_destroy_default;
    swl_zwp_idle_inhibit_manager_v1_destroy_impl =
        swl_zwp_idle_inhibit_manager_v1_destroy_default;
    swl_zwp_idle_inhibitor_v1_destroy_impl =
        swl_zwp_idle_inhibitor_v1_destroy_default;
    swl_xdg_system_bell_v1_destroy_impl = swl_xdg_system_bell_v1_destroy_default;
    swl_xdg_wm_dialog_v1_destroy_impl =
        swl_xdg_wm_dialog_v1_destroy_default;
    swl_xdg_dialog_v1_destroy_impl = swl_xdg_dialog_v1_destroy_default;
    swl_xdg_toplevel_drag_manager_v1_destroy_impl =
        swl_xdg_toplevel_drag_manager_v1_destroy_default;
    swl_xdg_toplevel_drag_v1_destroy_impl =
        swl_xdg_toplevel_drag_v1_destroy_default;
    swl_ext_foreign_toplevel_list_v1_destroy_impl =
        swl_ext_foreign_toplevel_list_v1_destroy_default;
    swl_ext_foreign_toplevel_handle_v1_destroy_impl =
        swl_ext_foreign_toplevel_handle_v1_destroy_default;
}

struct swl_test_desktop_request_record swl_test_desktop_request_record(void)
{
    return swl_test_desktop_request_latest;
}

struct swl_test_desktop_destroy_record swl_test_desktop_destroy_record(void)
{
    return swl_test_desktop_destroy_latest;
}
#endif
