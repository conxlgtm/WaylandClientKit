#include "wayland-client-kit-shims.h"
#include "generated/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1-client-protocol.h"
#include "generated/stable/xdg-shell/xdg-shell-client-protocol.h"
#include <stddef.h>

#ifdef SWL_ENABLE_TESTING
static char swl_test_xdg_toplevel_request_text[256];
static struct swl_test_xdg_positioner_request_record
    swl_test_xdg_positioner_request_latest;
static struct swl_test_xdg_toplevel_request_record
    swl_test_xdg_toplevel_request_latest;
static struct swl_test_xdg_popup_grab_record swl_test_xdg_popup_grab_latest;
static struct swl_test_xdg_destroy_record swl_test_xdg_destroy_latest;

static void swl_xdg_toplevel_set_title_default(
    struct xdg_toplevel *xdg_toplevel,
    const char *title)
{
    xdg_toplevel_set_title(xdg_toplevel, title);
}

static void swl_xdg_toplevel_set_app_id_default(
    struct xdg_toplevel *xdg_toplevel,
    const char *app_id)
{
    xdg_toplevel_set_app_id(xdg_toplevel, app_id);
}

static void swl_xdg_toplevel_show_window_menu_default(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial,
    int32_t x,
    int32_t y)
{
    xdg_toplevel_show_window_menu(xdg_toplevel, seat, serial, x, y);
}

static void swl_xdg_toplevel_move_default(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial)
{
    xdg_toplevel_move(xdg_toplevel, seat, serial);
}

static void swl_xdg_toplevel_resize_default(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial,
    uint32_t edges)
{
    xdg_toplevel_resize(xdg_toplevel, seat, serial, edges);
}

static void swl_xdg_toplevel_set_max_size_default(
    struct xdg_toplevel *xdg_toplevel,
    int32_t width,
    int32_t height)
{
    xdg_toplevel_set_max_size(xdg_toplevel, width, height);
}

static void swl_xdg_toplevel_set_min_size_default(
    struct xdg_toplevel *xdg_toplevel,
    int32_t width,
    int32_t height)
{
    xdg_toplevel_set_min_size(xdg_toplevel, width, height);
}

static void swl_xdg_toplevel_set_maximized_default(
    struct xdg_toplevel *xdg_toplevel)
{
    xdg_toplevel_set_maximized(xdg_toplevel);
}

static void swl_xdg_toplevel_unset_maximized_default(
    struct xdg_toplevel *xdg_toplevel)
{
    xdg_toplevel_unset_maximized(xdg_toplevel);
}

static void swl_xdg_toplevel_set_fullscreen_default(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_output *output)
{
    xdg_toplevel_set_fullscreen(xdg_toplevel, output);
}

static void swl_xdg_toplevel_unset_fullscreen_default(
    struct xdg_toplevel *xdg_toplevel)
{
    xdg_toplevel_unset_fullscreen(xdg_toplevel);
}

static void swl_xdg_toplevel_set_minimized_default(
    struct xdg_toplevel *xdg_toplevel)
{
    xdg_toplevel_set_minimized(xdg_toplevel);
}

static void swl_xdg_toplevel_destroy_default(
    struct xdg_toplevel *xdg_toplevel)
{
    xdg_toplevel_destroy(xdg_toplevel);
}

static void swl_xdg_positioner_set_size_default(
    struct xdg_positioner *positioner,
    int32_t width,
    int32_t height)
{
    xdg_positioner_set_size(positioner, width, height);
}

static void swl_xdg_positioner_set_anchor_rect_default(
    struct xdg_positioner *positioner,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    xdg_positioner_set_anchor_rect(positioner, x, y, width, height);
}

static void swl_xdg_positioner_set_anchor_default(
    struct xdg_positioner *positioner,
    uint32_t anchor)
{
    xdg_positioner_set_anchor(positioner, anchor);
}

static void swl_xdg_positioner_set_gravity_default(
    struct xdg_positioner *positioner,
    uint32_t gravity)
{
    xdg_positioner_set_gravity(positioner, gravity);
}

static void swl_xdg_positioner_set_constraint_adjustment_default(
    struct xdg_positioner *positioner,
    uint32_t constraint_adjustment)
{
    xdg_positioner_set_constraint_adjustment(positioner, constraint_adjustment);
}

static void swl_xdg_positioner_set_offset_default(
    struct xdg_positioner *positioner,
    int32_t x,
    int32_t y)
{
    xdg_positioner_set_offset(positioner, x, y);
}

static void swl_xdg_popup_grab_default(
    struct xdg_popup *popup,
    struct wl_seat *seat,
    uint32_t serial)
{
    xdg_popup_grab(popup, seat, serial);
}

static void swl_xdg_positioner_destroy_default(struct xdg_positioner *positioner)
{
    xdg_positioner_destroy(positioner);
}

static void swl_xdg_popup_destroy_default(struct xdg_popup *popup)
{
    xdg_popup_destroy(popup);
}

static void (*swl_xdg_positioner_set_size_impl)(
    struct xdg_positioner *positioner,
    int32_t width,
    int32_t height) = swl_xdg_positioner_set_size_default;
static void (*swl_xdg_positioner_set_anchor_rect_impl)(
    struct xdg_positioner *positioner,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height) = swl_xdg_positioner_set_anchor_rect_default;
static void (*swl_xdg_positioner_set_anchor_impl)(
    struct xdg_positioner *positioner,
    uint32_t anchor) = swl_xdg_positioner_set_anchor_default;
static void (*swl_xdg_positioner_set_gravity_impl)(
    struct xdg_positioner *positioner,
    uint32_t gravity) = swl_xdg_positioner_set_gravity_default;
static void (*swl_xdg_positioner_set_constraint_adjustment_impl)(
    struct xdg_positioner *positioner,
    uint32_t constraint_adjustment) =
        swl_xdg_positioner_set_constraint_adjustment_default;
static void (*swl_xdg_positioner_set_offset_impl)(
    struct xdg_positioner *positioner,
    int32_t x,
    int32_t y) = swl_xdg_positioner_set_offset_default;
static void (*swl_xdg_popup_grab_impl)(
    struct xdg_popup *popup,
    struct wl_seat *seat,
    uint32_t serial) = swl_xdg_popup_grab_default;
static void (*swl_xdg_positioner_destroy_impl)(struct xdg_positioner *positioner) =
    swl_xdg_positioner_destroy_default;
static void (*swl_xdg_popup_destroy_impl)(struct xdg_popup *popup) =
    swl_xdg_popup_destroy_default;
static void (*swl_xdg_toplevel_set_title_impl)(
    struct xdg_toplevel *xdg_toplevel,
    const char *title) = swl_xdg_toplevel_set_title_default;
static void (*swl_xdg_toplevel_set_app_id_impl)(
    struct xdg_toplevel *xdg_toplevel,
    const char *app_id) = swl_xdg_toplevel_set_app_id_default;
static void (*swl_xdg_toplevel_show_window_menu_impl)(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial,
    int32_t x,
    int32_t y) = swl_xdg_toplevel_show_window_menu_default;
static void (*swl_xdg_toplevel_move_impl)(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial) = swl_xdg_toplevel_move_default;
static void (*swl_xdg_toplevel_resize_impl)(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial,
    uint32_t edges) = swl_xdg_toplevel_resize_default;
static void (*swl_xdg_toplevel_set_max_size_impl)(
    struct xdg_toplevel *xdg_toplevel,
    int32_t width,
    int32_t height) = swl_xdg_toplevel_set_max_size_default;
static void (*swl_xdg_toplevel_set_min_size_impl)(
    struct xdg_toplevel *xdg_toplevel,
    int32_t width,
    int32_t height) = swl_xdg_toplevel_set_min_size_default;
static void (*swl_xdg_toplevel_set_maximized_impl)(
    struct xdg_toplevel *xdg_toplevel) =
        swl_xdg_toplevel_set_maximized_default;
static void (*swl_xdg_toplevel_unset_maximized_impl)(
    struct xdg_toplevel *xdg_toplevel) =
        swl_xdg_toplevel_unset_maximized_default;
static void (*swl_xdg_toplevel_set_fullscreen_impl)(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_output *output) = swl_xdg_toplevel_set_fullscreen_default;
static void (*swl_xdg_toplevel_unset_fullscreen_impl)(
    struct xdg_toplevel *xdg_toplevel) =
        swl_xdg_toplevel_unset_fullscreen_default;
static void (*swl_xdg_toplevel_set_minimized_impl)(
    struct xdg_toplevel *xdg_toplevel) =
        swl_xdg_toplevel_set_minimized_default;
static void (*swl_xdg_toplevel_destroy_impl)(
    struct xdg_toplevel *xdg_toplevel) =
        swl_xdg_toplevel_destroy_default;

static void swl_test_record_toplevel_request(
    struct xdg_toplevel *xdg_toplevel,
    enum swl_test_xdg_toplevel_request_kind kind,
    struct wl_seat *seat,
    struct wl_output *output,
    uint32_t serial,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height,
    uint32_t value)
{
    swl_test_xdg_toplevel_request_text[0] = '\0';
    swl_test_xdg_toplevel_request_latest.call_count += 1;
    swl_test_xdg_toplevel_request_latest.kind = kind;
    swl_test_xdg_toplevel_request_latest.toplevel = xdg_toplevel;
    swl_test_xdg_toplevel_request_latest.seat = seat;
    swl_test_xdg_toplevel_request_latest.output = output;
    swl_test_xdg_toplevel_request_latest.serial = serial;
    swl_test_xdg_toplevel_request_latest.x = x;
    swl_test_xdg_toplevel_request_latest.y = y;
    swl_test_xdg_toplevel_request_latest.width = width;
    swl_test_xdg_toplevel_request_latest.height = height;
    swl_test_xdg_toplevel_request_latest.value = value;
    swl_test_xdg_toplevel_request_latest.text = NULL;
}

static void swl_test_copy_toplevel_request_text(const char *text)
{
    if (text == NULL) {
        swl_test_xdg_toplevel_request_text[0] = '\0';
        swl_test_xdg_toplevel_request_latest.text =
            swl_test_xdg_toplevel_request_text;
        return;
    }

    size_t index = 0;
    while (index < sizeof(swl_test_xdg_toplevel_request_text) - 1
        && text[index] != '\0') {
        swl_test_xdg_toplevel_request_text[index] = text[index];
        index += 1;
    }
    swl_test_xdg_toplevel_request_text[index] = '\0';
    swl_test_xdg_toplevel_request_latest.text =
        swl_test_xdg_toplevel_request_text;
}

static void swl_test_xdg_toplevel_set_title_record(
    struct xdg_toplevel *xdg_toplevel,
    const char *title)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_TITLE,
        NULL, NULL, 0, 0, 0, 0, 0, 0);
    swl_test_copy_toplevel_request_text(title);
}

static void swl_test_xdg_toplevel_set_app_id_record(
    struct xdg_toplevel *xdg_toplevel,
    const char *app_id)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_APP_ID,
        NULL, NULL, 0, 0, 0, 0, 0, 0);
    swl_test_copy_toplevel_request_text(app_id);
}

static void swl_test_xdg_toplevel_show_window_menu_record(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial,
    int32_t x,
    int32_t y)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_SHOW_WINDOW_MENU,
        seat, NULL, serial, x, y, 0, 0, 0);
}

static void swl_test_xdg_toplevel_move_record(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_MOVE,
        seat, NULL, serial, 0, 0, 0, 0, 0);
}

static void swl_test_xdg_toplevel_resize_record(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial,
    uint32_t edges)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_RESIZE,
        seat, NULL, serial, 0, 0, 0, 0, edges);
}

static void swl_test_xdg_toplevel_set_max_size_record(
    struct xdg_toplevel *xdg_toplevel,
    int32_t width,
    int32_t height)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MAX_SIZE,
        NULL, NULL, 0, 0, 0, width, height, 0);
}

static void swl_test_xdg_toplevel_set_min_size_record(
    struct xdg_toplevel *xdg_toplevel,
    int32_t width,
    int32_t height)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MIN_SIZE,
        NULL, NULL, 0, 0, 0, width, height, 0);
}

static void swl_test_xdg_toplevel_set_maximized_record(
    struct xdg_toplevel *xdg_toplevel)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MAXIMIZED,
        NULL, NULL, 0, 0, 0, 0, 0, 0);
}

static void swl_test_xdg_toplevel_unset_maximized_record(
    struct xdg_toplevel *xdg_toplevel)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_UNSET_MAXIMIZED,
        NULL, NULL, 0, 0, 0, 0, 0, 0);
}

static void swl_test_xdg_toplevel_set_fullscreen_record(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_output *output)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_FULLSCREEN,
        NULL, output, 0, 0, 0, 0, 0, 0);
}

static void swl_test_xdg_toplevel_unset_fullscreen_record(
    struct xdg_toplevel *xdg_toplevel)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_UNSET_FULLSCREEN,
        NULL, NULL, 0, 0, 0, 0, 0, 0);
}

static void swl_test_xdg_toplevel_set_minimized_record(
    struct xdg_toplevel *xdg_toplevel)
{
    swl_test_record_toplevel_request(
        xdg_toplevel, SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MINIMIZED,
        NULL, NULL, 0, 0, 0, 0, 0, 0);
}

static void swl_test_record_positioner_request(
    struct xdg_positioner *positioner,
    enum swl_test_xdg_positioner_request_kind kind,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height,
    uint32_t value)
{
    swl_test_xdg_positioner_request_latest.call_count += 1;
    swl_test_xdg_positioner_request_latest.kind = kind;
    swl_test_xdg_positioner_request_latest.positioner = positioner;
    swl_test_xdg_positioner_request_latest.x = x;
    swl_test_xdg_positioner_request_latest.y = y;
    swl_test_xdg_positioner_request_latest.width = width;
    swl_test_xdg_positioner_request_latest.height = height;
    swl_test_xdg_positioner_request_latest.value = value;
}

static void swl_test_xdg_positioner_set_size_record(
    struct xdg_positioner *positioner,
    int32_t width,
    int32_t height)
{
    swl_test_record_positioner_request(
        positioner, SWL_TEST_XDG_POSITIONER_REQUEST_SIZE,
        0, 0, width, height, 0);
}

static void swl_test_xdg_positioner_set_anchor_rect_record(
    struct xdg_positioner *positioner,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_test_record_positioner_request(
        positioner, SWL_TEST_XDG_POSITIONER_REQUEST_ANCHOR_RECT,
        x, y, width, height, 0);
}

static void swl_test_xdg_positioner_set_anchor_record(
    struct xdg_positioner *positioner,
    uint32_t anchor)
{
    swl_test_record_positioner_request(
        positioner, SWL_TEST_XDG_POSITIONER_REQUEST_ANCHOR,
        0, 0, 0, 0, anchor);
}

static void swl_test_xdg_positioner_set_gravity_record(
    struct xdg_positioner *positioner,
    uint32_t gravity)
{
    swl_test_record_positioner_request(
        positioner, SWL_TEST_XDG_POSITIONER_REQUEST_GRAVITY,
        0, 0, 0, 0, gravity);
}

static void swl_test_xdg_positioner_set_constraint_adjustment_record(
    struct xdg_positioner *positioner,
    uint32_t constraint_adjustment)
{
    swl_test_record_positioner_request(
        positioner, SWL_TEST_XDG_POSITIONER_REQUEST_CONSTRAINT_ADJUSTMENT,
        0, 0, 0, 0, constraint_adjustment);
}

static void swl_test_xdg_positioner_set_offset_record(
    struct xdg_positioner *positioner,
    int32_t x,
    int32_t y)
{
    swl_test_record_positioner_request(
        positioner, SWL_TEST_XDG_POSITIONER_REQUEST_OFFSET,
        x, y, 0, 0, 0);
}

static void swl_test_record_xdg_popup_grab(
    struct xdg_popup *popup,
    struct wl_seat *seat,
    uint32_t serial)
{
    swl_test_xdg_popup_grab_latest.call_count += 1;
    swl_test_xdg_popup_grab_latest.popup = popup;
    swl_test_xdg_popup_grab_latest.seat = seat;
    swl_test_xdg_popup_grab_latest.serial = serial;
}

static void swl_test_xdg_positioner_destroy_record(struct xdg_positioner *positioner)
{
    swl_test_xdg_destroy_latest.call_count += 1;
    swl_test_xdg_destroy_latest.kind = SWL_TEST_XDG_DESTROY_POSITIONER;
    swl_test_xdg_destroy_latest.object = positioner;
}

static void swl_test_xdg_popup_destroy_record(struct xdg_popup *popup)
{
    swl_test_xdg_destroy_latest.call_count += 1;
    swl_test_xdg_destroy_latest.kind = SWL_TEST_XDG_DESTROY_POPUP;
    swl_test_xdg_destroy_latest.object = popup;
}

static void swl_test_xdg_toplevel_destroy_record(
    struct xdg_toplevel *xdg_toplevel)
{
    swl_test_xdg_destroy_latest.call_count += 1;
    swl_test_xdg_destroy_latest.kind = SWL_TEST_XDG_DESTROY_TOPLEVEL;
    swl_test_xdg_destroy_latest.object = xdg_toplevel;
}
#else
#define swl_xdg_positioner_set_size_impl xdg_positioner_set_size
#define swl_xdg_positioner_set_anchor_rect_impl xdg_positioner_set_anchor_rect
#define swl_xdg_positioner_set_anchor_impl xdg_positioner_set_anchor
#define swl_xdg_positioner_set_gravity_impl xdg_positioner_set_gravity
#define swl_xdg_positioner_set_constraint_adjustment_impl \
    xdg_positioner_set_constraint_adjustment
#define swl_xdg_positioner_set_offset_impl xdg_positioner_set_offset
#define swl_xdg_popup_grab_impl xdg_popup_grab
#define swl_xdg_positioner_destroy_impl xdg_positioner_destroy
#define swl_xdg_popup_destroy_impl xdg_popup_destroy
#define swl_xdg_toplevel_set_title_impl xdg_toplevel_set_title
#define swl_xdg_toplevel_set_app_id_impl xdg_toplevel_set_app_id
#define swl_xdg_toplevel_show_window_menu_impl xdg_toplevel_show_window_menu
#define swl_xdg_toplevel_move_impl xdg_toplevel_move
#define swl_xdg_toplevel_resize_impl xdg_toplevel_resize
#define swl_xdg_toplevel_set_max_size_impl xdg_toplevel_set_max_size
#define swl_xdg_toplevel_set_min_size_impl xdg_toplevel_set_min_size
#define swl_xdg_toplevel_set_maximized_impl xdg_toplevel_set_maximized
#define swl_xdg_toplevel_unset_maximized_impl xdg_toplevel_unset_maximized
#define swl_xdg_toplevel_set_fullscreen_impl xdg_toplevel_set_fullscreen
#define swl_xdg_toplevel_unset_fullscreen_impl xdg_toplevel_unset_fullscreen
#define swl_xdg_toplevel_set_minimized_impl xdg_toplevel_set_minimized
#define swl_xdg_toplevel_destroy_impl xdg_toplevel_destroy
#endif

struct xdg_surface *swl_xdg_wm_base_get_xdg_surface(
    struct xdg_wm_base *wm_base, struct wl_surface *surface)
{
    return xdg_wm_base_get_xdg_surface(wm_base, surface);
}

struct xdg_positioner *swl_xdg_wm_base_create_positioner(
    struct xdg_wm_base *wm_base)
{
    return xdg_wm_base_create_positioner(wm_base);
}

struct xdg_toplevel *swl_xdg_surface_get_toplevel(struct xdg_surface *xdg_surface)
{
    return xdg_surface_get_toplevel(xdg_surface);
}

struct xdg_popup *swl_xdg_surface_get_popup(
    struct xdg_surface *xdg_surface,
    struct xdg_surface *parent,
    struct xdg_positioner *positioner)
{
    return xdg_surface_get_popup(xdg_surface, parent, positioner);
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
    swl_xdg_toplevel_set_title_impl(xdg_toplevel, title);
}

void swl_xdg_toplevel_set_app_id(struct xdg_toplevel *xdg_toplevel, const char *app_id)
{
    swl_xdg_toplevel_set_app_id_impl(xdg_toplevel, app_id);
}

void swl_xdg_toplevel_show_window_menu(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial,
    int32_t x,
    int32_t y)
{
    swl_xdg_toplevel_show_window_menu_impl(xdg_toplevel, seat, serial, x, y);
}

void swl_xdg_toplevel_move(
    struct xdg_toplevel *xdg_toplevel, struct wl_seat *seat, uint32_t serial)
{
    swl_xdg_toplevel_move_impl(xdg_toplevel, seat, serial);
}

void swl_xdg_toplevel_resize(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial,
    uint32_t edges)
{
    swl_xdg_toplevel_resize_impl(xdg_toplevel, seat, serial, edges);
}

void swl_xdg_toplevel_set_max_size(
    struct xdg_toplevel *xdg_toplevel, int32_t width, int32_t height)
{
    swl_xdg_toplevel_set_max_size_impl(xdg_toplevel, width, height);
}

void swl_xdg_toplevel_set_min_size(
    struct xdg_toplevel *xdg_toplevel, int32_t width, int32_t height)
{
    swl_xdg_toplevel_set_min_size_impl(xdg_toplevel, width, height);
}

void swl_xdg_toplevel_set_maximized(struct xdg_toplevel *xdg_toplevel)
{
    swl_xdg_toplevel_set_maximized_impl(xdg_toplevel);
}

void swl_xdg_toplevel_unset_maximized(struct xdg_toplevel *xdg_toplevel)
{
    swl_xdg_toplevel_unset_maximized_impl(xdg_toplevel);
}

void swl_xdg_toplevel_set_fullscreen(
    struct xdg_toplevel *xdg_toplevel, struct wl_output *output)
{
    swl_xdg_toplevel_set_fullscreen_impl(xdg_toplevel, output);
}

void swl_xdg_toplevel_unset_fullscreen(struct xdg_toplevel *xdg_toplevel)
{
    swl_xdg_toplevel_unset_fullscreen_impl(xdg_toplevel);
}

void swl_xdg_toplevel_set_minimized(struct xdg_toplevel *xdg_toplevel)
{
    swl_xdg_toplevel_set_minimized_impl(xdg_toplevel);
}

void swl_xdg_positioner_set_size(
    struct xdg_positioner *positioner, int32_t width, int32_t height)
{
    swl_xdg_positioner_set_size_impl(positioner, width, height);
}

void swl_xdg_positioner_set_anchor_rect(
    struct xdg_positioner *positioner,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height)
{
    swl_xdg_positioner_set_anchor_rect_impl(positioner, x, y, width, height);
}

void swl_xdg_positioner_set_anchor(
    struct xdg_positioner *positioner, uint32_t anchor)
{
    swl_xdg_positioner_set_anchor_impl(positioner, anchor);
}

void swl_xdg_positioner_set_gravity(
    struct xdg_positioner *positioner, uint32_t gravity)
{
    swl_xdg_positioner_set_gravity_impl(positioner, gravity);
}

void swl_xdg_positioner_set_constraint_adjustment(
    struct xdg_positioner *positioner, uint32_t constraint_adjustment)
{
    swl_xdg_positioner_set_constraint_adjustment_impl(
        positioner, constraint_adjustment);
}

void swl_xdg_positioner_set_offset(
    struct xdg_positioner *positioner, int32_t x, int32_t y)
{
    swl_xdg_positioner_set_offset_impl(positioner, x, y);
}

void swl_xdg_popup_grab(
    struct xdg_popup *popup, struct wl_seat *seat, uint32_t serial)
{
    swl_xdg_popup_grab_impl(popup, seat, serial);
}

void swl_xdg_surface_destroy(struct xdg_surface *xdg_surface)
{
    xdg_surface_destroy(xdg_surface);
}

void swl_xdg_toplevel_destroy(struct xdg_toplevel *xdg_toplevel)
{
    swl_xdg_toplevel_destroy_impl(xdg_toplevel);
}

void swl_xdg_positioner_destroy(struct xdg_positioner *positioner)
{
    swl_xdg_positioner_destroy_impl(positioner);
}

void swl_xdg_popup_destroy(struct xdg_popup *popup)
{
    swl_xdg_popup_destroy_impl(popup);
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

#ifdef SWL_ENABLE_TESTING
void swl_test_xdg_request_recording_begin(void)
{
    swl_test_xdg_toplevel_request_text[0] = '\0';
    swl_test_xdg_positioner_request_latest =
        (struct swl_test_xdg_positioner_request_record){
            .kind = SWL_TEST_XDG_POSITIONER_REQUEST_NONE,
        };
    swl_test_xdg_toplevel_request_latest =
        (struct swl_test_xdg_toplevel_request_record){
            .kind = SWL_TEST_XDG_TOPLEVEL_REQUEST_NONE,
        };
    swl_test_xdg_popup_grab_latest =
        (struct swl_test_xdg_popup_grab_record){0};
    swl_test_xdg_destroy_latest =
        (struct swl_test_xdg_destroy_record){
            .kind = SWL_TEST_XDG_DESTROY_NONE,
        };

    swl_xdg_positioner_set_size_impl =
        swl_test_xdg_positioner_set_size_record;
    swl_xdg_positioner_set_anchor_rect_impl =
        swl_test_xdg_positioner_set_anchor_rect_record;
    swl_xdg_positioner_set_anchor_impl =
        swl_test_xdg_positioner_set_anchor_record;
    swl_xdg_positioner_set_gravity_impl =
        swl_test_xdg_positioner_set_gravity_record;
    swl_xdg_positioner_set_constraint_adjustment_impl =
        swl_test_xdg_positioner_set_constraint_adjustment_record;
    swl_xdg_positioner_set_offset_impl =
        swl_test_xdg_positioner_set_offset_record;
    swl_xdg_popup_grab_impl = swl_test_record_xdg_popup_grab;
    swl_xdg_positioner_destroy_impl = swl_test_xdg_positioner_destroy_record;
    swl_xdg_popup_destroy_impl = swl_test_xdg_popup_destroy_record;
    swl_xdg_toplevel_set_title_impl =
        swl_test_xdg_toplevel_set_title_record;
    swl_xdg_toplevel_set_app_id_impl =
        swl_test_xdg_toplevel_set_app_id_record;
    swl_xdg_toplevel_show_window_menu_impl =
        swl_test_xdg_toplevel_show_window_menu_record;
    swl_xdg_toplevel_move_impl =
        swl_test_xdg_toplevel_move_record;
    swl_xdg_toplevel_resize_impl =
        swl_test_xdg_toplevel_resize_record;
    swl_xdg_toplevel_set_max_size_impl =
        swl_test_xdg_toplevel_set_max_size_record;
    swl_xdg_toplevel_set_min_size_impl =
        swl_test_xdg_toplevel_set_min_size_record;
    swl_xdg_toplevel_set_maximized_impl =
        swl_test_xdg_toplevel_set_maximized_record;
    swl_xdg_toplevel_unset_maximized_impl =
        swl_test_xdg_toplevel_unset_maximized_record;
    swl_xdg_toplevel_set_fullscreen_impl =
        swl_test_xdg_toplevel_set_fullscreen_record;
    swl_xdg_toplevel_unset_fullscreen_impl =
        swl_test_xdg_toplevel_unset_fullscreen_record;
    swl_xdg_toplevel_set_minimized_impl =
        swl_test_xdg_toplevel_set_minimized_record;
    swl_xdg_toplevel_destroy_impl =
        swl_test_xdg_toplevel_destroy_record;
}

void swl_test_xdg_request_recording_end(void)
{
    swl_xdg_positioner_set_size_impl =
        swl_xdg_positioner_set_size_default;
    swl_xdg_positioner_set_anchor_rect_impl =
        swl_xdg_positioner_set_anchor_rect_default;
    swl_xdg_positioner_set_anchor_impl =
        swl_xdg_positioner_set_anchor_default;
    swl_xdg_positioner_set_gravity_impl =
        swl_xdg_positioner_set_gravity_default;
    swl_xdg_positioner_set_constraint_adjustment_impl =
        swl_xdg_positioner_set_constraint_adjustment_default;
    swl_xdg_positioner_set_offset_impl =
        swl_xdg_positioner_set_offset_default;
    swl_xdg_popup_grab_impl = swl_xdg_popup_grab_default;
    swl_xdg_positioner_destroy_impl = swl_xdg_positioner_destroy_default;
    swl_xdg_popup_destroy_impl = swl_xdg_popup_destroy_default;
    swl_xdg_toplevel_set_title_impl =
        swl_xdg_toplevel_set_title_default;
    swl_xdg_toplevel_set_app_id_impl =
        swl_xdg_toplevel_set_app_id_default;
    swl_xdg_toplevel_show_window_menu_impl =
        swl_xdg_toplevel_show_window_menu_default;
    swl_xdg_toplevel_move_impl =
        swl_xdg_toplevel_move_default;
    swl_xdg_toplevel_resize_impl =
        swl_xdg_toplevel_resize_default;
    swl_xdg_toplevel_set_max_size_impl =
        swl_xdg_toplevel_set_max_size_default;
    swl_xdg_toplevel_set_min_size_impl =
        swl_xdg_toplevel_set_min_size_default;
    swl_xdg_toplevel_set_maximized_impl =
        swl_xdg_toplevel_set_maximized_default;
    swl_xdg_toplevel_unset_maximized_impl =
        swl_xdg_toplevel_unset_maximized_default;
    swl_xdg_toplevel_set_fullscreen_impl =
        swl_xdg_toplevel_set_fullscreen_default;
    swl_xdg_toplevel_unset_fullscreen_impl =
        swl_xdg_toplevel_unset_fullscreen_default;
    swl_xdg_toplevel_set_minimized_impl =
        swl_xdg_toplevel_set_minimized_default;
    swl_xdg_toplevel_destroy_impl =
        swl_xdg_toplevel_destroy_default;
}

struct swl_test_xdg_positioner_request_record
swl_test_xdg_positioner_request_record(void)
{
    return swl_test_xdg_positioner_request_latest;
}

struct swl_test_xdg_toplevel_request_record
swl_test_xdg_toplevel_request_record(void)
{
    return swl_test_xdg_toplevel_request_latest;
}

struct swl_test_xdg_popup_grab_record swl_test_xdg_popup_grab_record(void)
{
    return swl_test_xdg_popup_grab_latest;
}

struct swl_test_xdg_destroy_record swl_test_xdg_destroy_record(void)
{
    return swl_test_xdg_destroy_latest;
}
#endif
