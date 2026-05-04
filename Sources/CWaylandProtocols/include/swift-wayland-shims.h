#pragma once

#ifndef __linux__
#error "SwiftWayland currently supports Linux only."
#endif

#include <stdint.h>
#include <wayland-client.h>

#if !defined(SWL_ENABLE_TESTING) && !defined(NDEBUG)
#define SWL_ENABLE_TESTING 1
#endif

struct xdg_wm_base;
struct xdg_surface;
struct xdg_toplevel;
struct xdg_positioner;
struct xdg_popup;
struct zxdg_decoration_manager_v1;
struct zxdg_toplevel_decoration_v1;
struct wp_viewporter;
struct wp_viewport;
struct wp_fractional_scale_manager_v1;
struct wp_fractional_scale_v1;

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/*  Registry bind wrappers                                            */
/* ------------------------------------------------------------------ */

struct wl_compositor *swl_registry_bind_wl_compositor(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wl_shm *swl_registry_bind_wl_shm(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct xdg_wm_base *swl_registry_bind_xdg_wm_base(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct zxdg_decoration_manager_v1 *swl_registry_bind_zxdg_decoration_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_viewporter *swl_registry_bind_wp_viewporter(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_fractional_scale_manager_v1 *swl_registry_bind_wp_fractional_scale_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wl_seat *swl_registry_bind_wl_seat(
    struct wl_registry *registry, uint32_t name, uint32_t version);

/* ------------------------------------------------------------------ */
/*  Core request wrappers                                             */
/* ------------------------------------------------------------------ */

struct wl_surface *swl_compositor_create_surface(struct wl_compositor *compositor);

struct wl_shm_pool *swl_shm_create_pool(struct wl_shm *shm, int32_t fd, int32_t size);

struct wl_buffer *swl_shm_pool_create_buffer(
    struct wl_shm_pool *pool, int32_t offset, int32_t width,
    int32_t height, int32_t stride, uint32_t format);

struct wl_callback *swl_surface_frame(struct wl_surface *surface);

struct wl_pointer *swl_seat_get_pointer(struct wl_seat *seat);
struct wl_keyboard *swl_seat_get_keyboard(struct wl_seat *seat);
struct wl_touch *swl_seat_get_touch(struct wl_seat *seat);
void swl_pointer_set_cursor(
    struct wl_pointer *pointer,
    uint32_t serial,
    struct wl_surface *surface,
    int32_t hotspot_x,
    int32_t hotspot_y);

void swl_surface_attach(
    struct wl_surface *surface, struct wl_buffer *buffer, int32_t x, int32_t y);
void swl_surface_commit(struct wl_surface *surface);
void swl_surface_damage_buffer(
    struct wl_surface *surface, int32_t x, int32_t y,
    int32_t width, int32_t height);
// for older wl_surface versions
void swl_surface_damage(struct wl_surface *surface, int32_t xd, int32_t y, int32_t width, int32_t height);
void swl_surface_set_buffer_scale(struct wl_surface *surface, int32_t scale);

uint32_t swl_shm_format_xrgb8888(void);
uint32_t swl_shm_format_argb8888(void);

// create file backed memory for sharing with Wayland
int swl_memfd_create(const char *name, unsigned int flags);
// close on exec flags
unsigned int swl_mfd_cloexec(void);

/* ------------------------------------------------------------------ */
/*  XDG request wrappers                                              */
/* ------------------------------------------------------------------ */

struct xdg_surface *swl_xdg_wm_base_get_xdg_surface(
    struct xdg_wm_base *wm_base, struct wl_surface *surface);
struct xdg_positioner *swl_xdg_wm_base_create_positioner(
    struct xdg_wm_base *wm_base);

struct xdg_toplevel *swl_xdg_surface_get_toplevel(struct xdg_surface *xdg_surface);
struct xdg_popup *swl_xdg_surface_get_popup(
    struct xdg_surface *xdg_surface,
    struct xdg_surface *parent,
    struct xdg_positioner *positioner);

void swl_xdg_wm_base_pong(struct xdg_wm_base *wm_base, uint32_t serial);
void swl_xdg_surface_ack_configure(struct xdg_surface *xdg_surface, uint32_t serial);
void swl_xdg_toplevel_set_title(struct xdg_toplevel *xdg_toplevel, const char *title);
void swl_xdg_toplevel_set_app_id(struct xdg_toplevel *xdg_toplevel, const char *app_id);
void swl_xdg_positioner_set_size(
    struct xdg_positioner *positioner, int32_t width, int32_t height);
void swl_xdg_positioner_set_anchor_rect(
    struct xdg_positioner *positioner,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height);
void swl_xdg_positioner_set_anchor(
    struct xdg_positioner *positioner, uint32_t anchor);
void swl_xdg_positioner_set_gravity(
    struct xdg_positioner *positioner, uint32_t gravity);
void swl_xdg_positioner_set_constraint_adjustment(
    struct xdg_positioner *positioner, uint32_t constraint_adjustment);
void swl_xdg_positioner_set_offset(
    struct xdg_positioner *positioner, int32_t x, int32_t y);
void swl_xdg_popup_grab(
    struct xdg_popup *popup, struct wl_seat *seat, uint32_t serial);

/* ------------------------------------------------------------------ */
/*  XDG decoration request wrappers                                   */
/* ------------------------------------------------------------------ */

struct zxdg_toplevel_decoration_v1 *swl_zxdg_decoration_manager_v1_get_toplevel_decoration(
    struct zxdg_decoration_manager_v1 *manager,
    struct xdg_toplevel *xdg_toplevel);

void swl_zxdg_toplevel_decoration_v1_set_mode(
    struct zxdg_toplevel_decoration_v1 *decoration, uint32_t mode);
void swl_zxdg_toplevel_decoration_v1_unset_mode(
    struct zxdg_toplevel_decoration_v1 *decoration);

uint32_t swl_zxdg_toplevel_decoration_v1_mode_client_side(void);
uint32_t swl_zxdg_toplevel_decoration_v1_mode_server_side(void);

/* ------------------------------------------------------------------ */
/*  Scale and viewport request wrappers                               */
/* ------------------------------------------------------------------ */

struct wp_viewport *swl_wp_viewporter_get_viewport(
    struct wp_viewporter *viewporter,
    struct wl_surface *surface);
void swl_wp_viewport_set_destination(
    struct wp_viewport *viewport,
    int32_t width,
    int32_t height);

struct wp_fractional_scale_v1 *swl_wp_fractional_scale_manager_v1_get_fractional_scale(
    struct wp_fractional_scale_manager_v1 *manager,
    struct wl_surface *surface);

/* ------------------------------------------------------------------ */
/*  Destroy / release wrappers                                        */
/* ------------------------------------------------------------------ */

void swl_registry_destroy(struct wl_registry *registry);
void swl_callback_destroy(struct wl_callback *callback);
void swl_compositor_destroy(struct wl_compositor *compositor);
void swl_shm_destroy(struct wl_shm *shm);
void swl_buffer_destroy(struct wl_buffer *buffer);
void swl_surface_destroy(struct wl_surface *surface);
void swl_shm_pool_destroy(struct wl_shm_pool *pool);
void swl_pointer_release(struct wl_pointer *pointer);
void swl_keyboard_release(struct wl_keyboard *keyboard);
void swl_touch_release(struct wl_touch *touch);
void swl_seat_destroy(struct wl_seat *seat);
void swl_seat_release(struct wl_seat *seat);
void swl_xdg_surface_destroy(struct xdg_surface *xdg_surface);
void swl_xdg_toplevel_destroy(struct xdg_toplevel *xdg_toplevel);
void swl_xdg_positioner_destroy(struct xdg_positioner *positioner);
void swl_xdg_popup_destroy(struct xdg_popup *popup);
void swl_xdg_wm_base_destroy(struct xdg_wm_base *wm_base);
void swl_zxdg_toplevel_decoration_v1_destroy(
    struct zxdg_toplevel_decoration_v1 *decoration);
void swl_zxdg_decoration_manager_v1_destroy(
    struct zxdg_decoration_manager_v1 *manager);
void swl_wp_viewport_destroy(struct wp_viewport *viewport);
void swl_wp_viewporter_destroy(struct wp_viewporter *viewporter);
void swl_wp_fractional_scale_v1_destroy(struct wp_fractional_scale_v1 *fractional_scale);
void swl_wp_fractional_scale_manager_v1_destroy(
    struct wp_fractional_scale_manager_v1 *manager);

/* ------------------------------------------------------------------ */
/*  Display wrappers                                                  */
/* ------------------------------------------------------------------ */

struct swl_protocol_error_details {
    int32_t     code;
    uint32_t    object_id;
    const char *interface_name;
};

struct wl_registry *swl_display_get_registry(struct wl_display *display);
struct wl_callback *swl_display_sync(struct wl_display *display);

struct wl_event_queue *swl_display_create_event_queue(struct wl_display *display);
void swl_event_queue_destroy(struct wl_event_queue *queue);
struct wl_display *swl_display_create_wrapper(struct wl_display *display);
void swl_display_wrapper_set_queue(
    struct wl_display *display_wrapper,
    struct wl_event_queue *queue);
void swl_display_wrapper_destroy(struct wl_display *display_wrapper);
int swl_display_dispatch_event_queue_pending(
    struct wl_display *display,
    struct wl_event_queue *queue);
int swl_display_prepare_read_event_queue(
    struct wl_display *display,
    struct wl_event_queue *queue);

uint32_t swl_proxy_get_version(void *proxy);
uint32_t swl_proxy_get_id(void *proxy);
struct wl_event_queue *swl_proxy_get_queue_raw(void *proxy);

int swl_display_get_protocol_error_details(
    struct wl_display *display, struct swl_protocol_error_details *details);

/* ------------------------------------------------------------------ */
/*  Listener callback typedefs                                        */
/* ------------------------------------------------------------------ */

/* Registry */
typedef void (*swl_registry_global_fn)(
    void *data, struct wl_registry *registry, uint32_t name,
    const char *interface, uint32_t version);
typedef void (*swl_registry_global_remove_fn)(
    void *data, struct wl_registry *registry, uint32_t name);

/* Core objects */
typedef void (*swl_callback_done_fn)(
    void *data, struct wl_callback *callback, uint32_t callback_data);
typedef void (*swl_buffer_release_fn)(void *data, struct wl_buffer *buffer);
typedef void (*swl_surface_preferred_buffer_scale_fn)(
    void *data, struct wl_surface *surface, int32_t factor);

/* XDG shell */
typedef void (*swl_xdg_wm_base_ping_fn)(
    void *data, struct xdg_wm_base *wm_base, uint32_t serial);
typedef void (*swl_xdg_surface_configure_fn)(
    void *data, struct xdg_surface *xdg_surface, uint32_t serial);
typedef void (*swl_xdg_toplevel_configure_fn)(
    void *data, struct xdg_toplevel *xdg_toplevel,
    int32_t width, int32_t height, struct wl_array *states);
typedef void (*swl_xdg_toplevel_close_fn)(
    void *data, struct xdg_toplevel *xdg_toplevel);
typedef void (*swl_xdg_toplevel_configure_bounds_fn)(
    void *data, struct xdg_toplevel *xdg_toplevel,
    int32_t width, int32_t height);
typedef void (*swl_xdg_toplevel_wm_capabilities_fn)(
    void *data, struct xdg_toplevel *xdg_toplevel,
    struct wl_array *capabilities);
typedef void (*swl_xdg_popup_configure_fn)(
    void *data,
    struct xdg_popup *popup,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height);
typedef void (*swl_xdg_popup_done_fn)(
    void *data, struct xdg_popup *popup);
typedef void (*swl_xdg_popup_repositioned_fn)(
    void *data, struct xdg_popup *popup, uint32_t token);

/* XDG decoration */
typedef void (*swl_zxdg_toplevel_decoration_v1_configure_fn)(
    void *data, struct zxdg_toplevel_decoration_v1 *decoration, uint32_t mode);

/* Fractional scale */
typedef void (*swl_wp_fractional_scale_v1_preferred_scale_fn)(
    void *data, struct wp_fractional_scale_v1 *fractional_scale, uint32_t scale);

/* Seat */
typedef void (*swl_seat_capabilities_fn)(
    void *data, struct wl_seat *seat, uint32_t capabilities);
typedef void (*swl_seat_name_fn)(
    void *data, struct wl_seat *seat, const char *name);

/* Pointer */
typedef void (*swl_pointer_enter_fn)(
    void *data, struct wl_pointer *pointer, uint32_t serial,
    struct wl_surface *surface, wl_fixed_t surface_x, wl_fixed_t surface_y);
typedef void (*swl_pointer_leave_fn)(
    void *data, struct wl_pointer *pointer,
    uint32_t serial, struct wl_surface *surface);
typedef void (*swl_pointer_motion_fn)(
    void *data, struct wl_pointer *pointer,
    uint32_t time, wl_fixed_t surface_x, wl_fixed_t surface_y);
typedef void (*swl_pointer_button_fn)(
    void *data, struct wl_pointer *pointer,
    uint32_t serial, uint32_t time, uint32_t button, uint32_t state);
typedef void (*swl_pointer_axis_fn)(
    void *data, struct wl_pointer *pointer,
    uint32_t time, uint32_t axis, wl_fixed_t value);
typedef void (*swl_pointer_frame_fn)(void *data, struct wl_pointer *pointer);
typedef void (*swl_pointer_axis_source_fn)(
    void *data, struct wl_pointer *pointer, uint32_t axis_source);
typedef void (*swl_pointer_axis_stop_fn)(
    void *data, struct wl_pointer *pointer, uint32_t time, uint32_t axis);
typedef void (*swl_pointer_axis_discrete_fn)(
    void *data, struct wl_pointer *pointer, uint32_t axis, int32_t discrete);
typedef void (*swl_pointer_axis_value120_fn)(
    void *data, struct wl_pointer *pointer, uint32_t axis, int32_t value120);
typedef void (*swl_pointer_axis_relative_direction_fn)(
    void *data, struct wl_pointer *pointer,
    uint32_t axis, uint32_t direction);

/* Keyboard */
typedef void (*swl_keyboard_keymap_fn)(
    void *data, struct wl_keyboard *keyboard,
    uint32_t format, int32_t fd, uint32_t size);
typedef void (*swl_keyboard_enter_fn)(
    void *data, struct wl_keyboard *keyboard,
    uint32_t serial, struct wl_surface *surface, struct wl_array *keys);
typedef void (*swl_keyboard_leave_fn)(
    void *data, struct wl_keyboard *keyboard,
    uint32_t serial, struct wl_surface *surface);
typedef void (*swl_keyboard_key_fn)(
    void *data, struct wl_keyboard *keyboard,
    uint32_t serial, uint32_t time, uint32_t key, uint32_t state);
typedef void (*swl_keyboard_modifiers_fn)(
    void *data, struct wl_keyboard *keyboard, uint32_t serial,
    uint32_t mods_depressed, uint32_t mods_latched,
    uint32_t mods_locked, uint32_t group);
typedef void (*swl_keyboard_repeat_info_fn)(
    void *data, struct wl_keyboard *keyboard, int32_t rate, int32_t delay);

/* Touch */
typedef void (*swl_touch_down_fn)(
    void *data, struct wl_touch *touch, uint32_t serial, uint32_t time,
    struct wl_surface *surface, int32_t id, wl_fixed_t x, wl_fixed_t y);
typedef void (*swl_touch_up_fn)(
    void *data, struct wl_touch *touch,
    uint32_t serial, uint32_t time, int32_t id);
typedef void (*swl_touch_motion_fn)(
    void *data, struct wl_touch *touch,
    uint32_t time, int32_t id, wl_fixed_t x, wl_fixed_t y);
typedef void (*swl_touch_frame_fn)(void *data, struct wl_touch *touch);
typedef void (*swl_touch_cancel_fn)(void *data, struct wl_touch *touch);
typedef void (*swl_touch_shape_fn)(
    void *data, struct wl_touch *touch,
    int32_t id, wl_fixed_t major, wl_fixed_t minor);
typedef void (*swl_touch_orientation_fn)(
    void *data, struct wl_touch *touch, int32_t id, wl_fixed_t orientation);

/* ------------------------------------------------------------------ */
/*  Callback bundle structs                                           */
/* ------------------------------------------------------------------ */

struct swl_registry_listener_callbacks {
    swl_registry_global_fn        global;
    swl_registry_global_remove_fn global_remove;
    void                         *data;
};

struct swl_callback_listener_callbacks {
    swl_callback_done_fn done;
    void                *data;
};

struct swl_buffer_listener_callbacks {
    swl_buffer_release_fn release;
    void                 *data;
};

struct swl_surface_listener_callbacks {
    swl_surface_preferred_buffer_scale_fn preferred_buffer_scale;
    void                                 *data;
};

struct swl_xdg_wm_base_listener_callbacks {
    swl_xdg_wm_base_ping_fn ping;
    void                    *data;
};

struct swl_xdg_surface_listener_callbacks {
    swl_xdg_surface_configure_fn configure;
    void                        *data;
};

struct swl_xdg_toplevel_listener_callbacks {
    swl_xdg_toplevel_configure_fn        configure;
    swl_xdg_toplevel_close_fn            close;
    swl_xdg_toplevel_configure_bounds_fn configure_bounds;
    swl_xdg_toplevel_wm_capabilities_fn  wm_capabilities;
    void                                *data;
};

struct swl_xdg_popup_listener_callbacks {
    swl_xdg_popup_configure_fn    configure;
    swl_xdg_popup_done_fn         popup_done;
    swl_xdg_popup_repositioned_fn repositioned;
    void                         *data;
};

struct swl_zxdg_toplevel_decoration_v1_listener_callbacks {
    swl_zxdg_toplevel_decoration_v1_configure_fn configure;
    void                                        *data;
};

struct swl_wp_fractional_scale_v1_listener_callbacks {
    swl_wp_fractional_scale_v1_preferred_scale_fn preferred_scale;
    void                                         *data;
};

struct swl_seat_listener_callbacks {
    swl_seat_capabilities_fn capabilities;
    swl_seat_name_fn         name;
    void                    *data;
};

struct swl_pointer_listener_callbacks {
    swl_pointer_enter_fn                  enter;
    swl_pointer_leave_fn                  leave;
    swl_pointer_motion_fn                 motion;
    swl_pointer_button_fn                 button;
    swl_pointer_axis_fn                   axis;
    swl_pointer_frame_fn                  frame;
    swl_pointer_axis_source_fn            axis_source;
    swl_pointer_axis_stop_fn              axis_stop;
    swl_pointer_axis_discrete_fn          axis_discrete;
    swl_pointer_axis_value120_fn          axis_value120;
    swl_pointer_axis_relative_direction_fn axis_relative_direction;
    void                                  *data;
};

struct swl_keyboard_listener_callbacks {
    swl_keyboard_keymap_fn      keymap;
    swl_keyboard_enter_fn       enter;
    swl_keyboard_leave_fn       leave;
    swl_keyboard_key_fn         key;
    swl_keyboard_modifiers_fn   modifiers;
    swl_keyboard_repeat_info_fn repeat_info;
    void                       *data;
};

struct swl_touch_listener_callbacks {
    swl_touch_down_fn        down;
    swl_touch_up_fn          up;
    swl_touch_motion_fn      motion;
    swl_touch_frame_fn       frame;
    swl_touch_cancel_fn      cancel;
    swl_touch_shape_fn       shape;
    swl_touch_orientation_fn orientation;
    void                    *data;
};

/* ------------------------------------------------------------------ */
/*  Typed listener installers                                         */
/* ------------------------------------------------------------------ */

int swl_registry_add_listener(
    struct wl_registry *registry,
    const struct swl_registry_listener_callbacks *callbacks);

int swl_callback_add_listener(
    struct wl_callback *callback,
    const struct swl_callback_listener_callbacks *callbacks);

int swl_buffer_add_listener(
    struct wl_buffer *buffer,
    const struct swl_buffer_listener_callbacks *callbacks);

int swl_surface_add_listener(
    struct wl_surface *surface,
    const struct swl_surface_listener_callbacks *callbacks);

int swl_xdg_wm_base_add_listener(
    struct xdg_wm_base *wm_base,
    const struct swl_xdg_wm_base_listener_callbacks *callbacks);

int swl_xdg_surface_add_listener(
    struct xdg_surface *xdg_surface,
    const struct swl_xdg_surface_listener_callbacks *callbacks);

int swl_xdg_toplevel_add_listener(
    struct xdg_toplevel *xdg_toplevel,
    const struct swl_xdg_toplevel_listener_callbacks *callbacks);

int swl_xdg_popup_add_listener(
    struct xdg_popup *popup,
    const struct swl_xdg_popup_listener_callbacks *callbacks);

int swl_zxdg_toplevel_decoration_v1_add_listener(
    struct zxdg_toplevel_decoration_v1 *decoration,
    const struct swl_zxdg_toplevel_decoration_v1_listener_callbacks *callbacks);

int swl_wp_fractional_scale_v1_add_listener(
    struct wp_fractional_scale_v1 *fractional_scale,
    const struct swl_wp_fractional_scale_v1_listener_callbacks *callbacks);

int swl_seat_add_listener(
    struct wl_seat *seat,
    const struct swl_seat_listener_callbacks *callbacks);

int swl_pointer_add_listener(
    struct wl_pointer *pointer,
    const struct swl_pointer_listener_callbacks *callbacks);

int swl_keyboard_add_listener(
    struct wl_keyboard *keyboard,
    const struct swl_keyboard_listener_callbacks *callbacks);

int swl_touch_add_listener(
    struct wl_touch *touch,
    const struct swl_touch_listener_callbacks *callbacks);

#ifdef SWL_ENABLE_TESTING
/* ------------------------------------------------------------------ */
/*  Test-only scale shim contracts                                    */
/* ------------------------------------------------------------------ */

struct swl_test_surface_preferred_buffer_scale_record {
    int32_t            call_count;
    void              *data;
    struct wl_surface *surface;
    int32_t            factor;
};

struct swl_test_fractional_preferred_scale_record {
    int32_t                        call_count;
    void                          *data;
    struct wp_fractional_scale_v1 *fractional_scale;
    uint32_t                       scale;
};

struct swl_test_viewport_destination_record {
    int32_t             call_count;
    struct wp_viewport *viewport;
    int32_t             width;
    int32_t             height;
};

enum swl_test_scale_destroy_kind {
    SWL_TEST_SCALE_DESTROY_NONE = 0,
    SWL_TEST_SCALE_DESTROY_VIEWPORT = 1,
    SWL_TEST_SCALE_DESTROY_VIEWPORTER = 2,
    SWL_TEST_SCALE_DESTROY_FRACTIONAL_SCALE = 3,
    SWL_TEST_SCALE_DESTROY_FRACTIONAL_SCALE_MANAGER = 4,
};

struct swl_test_scale_destroy_record {
    int32_t                          call_count;
    enum swl_test_scale_destroy_kind kind;
    void                            *object;
};

struct swl_test_xdg_popup_configure_record {
    int32_t           call_count;
    void             *data;
    struct xdg_popup *popup;
    int32_t           x;
    int32_t           y;
    int32_t           width;
    int32_t           height;
};

struct swl_test_xdg_popup_done_record {
    int32_t           call_count;
    void             *data;
    struct xdg_popup *popup;
};

struct swl_test_xdg_popup_repositioned_record {
    int32_t           call_count;
    void             *data;
    struct xdg_popup *popup;
    uint32_t          token;
};

enum swl_test_xdg_positioner_request_kind {
    SWL_TEST_XDG_POSITIONER_REQUEST_NONE = 0,
    SWL_TEST_XDG_POSITIONER_REQUEST_SIZE = 1,
    SWL_TEST_XDG_POSITIONER_REQUEST_ANCHOR_RECT = 2,
    SWL_TEST_XDG_POSITIONER_REQUEST_ANCHOR = 3,
    SWL_TEST_XDG_POSITIONER_REQUEST_GRAVITY = 4,
    SWL_TEST_XDG_POSITIONER_REQUEST_CONSTRAINT_ADJUSTMENT = 5,
    SWL_TEST_XDG_POSITIONER_REQUEST_OFFSET = 6,
};

struct swl_test_xdg_positioner_request_record {
    int32_t                                    call_count;
    enum swl_test_xdg_positioner_request_kind kind;
    struct xdg_positioner                    *positioner;
    int32_t                                    x;
    int32_t                                    y;
    int32_t                                    width;
    int32_t                                    height;
    uint32_t                                   value;
};

struct swl_test_xdg_popup_grab_record {
    int32_t           call_count;
    struct xdg_popup *popup;
    struct wl_seat   *seat;
    uint32_t          serial;
};

enum swl_test_xdg_destroy_kind {
    SWL_TEST_XDG_DESTROY_NONE = 0,
    SWL_TEST_XDG_DESTROY_POSITIONER = 1,
    SWL_TEST_XDG_DESTROY_POPUP = 2,
};

struct swl_test_xdg_destroy_record {
    int32_t                        call_count;
    enum swl_test_xdg_destroy_kind kind;
    void                          *object;
};

int swl_test_surface_listener_emit_preferred_buffer_scale(
    void *data,
    struct wl_surface *surface,
    int32_t factor,
    struct swl_test_surface_preferred_buffer_scale_record *record);

void swl_test_fractional_scale_listener_emit_preferred_scale(
    void *data,
    struct wp_fractional_scale_v1 *fractional_scale,
    uint32_t scale,
    struct swl_test_fractional_preferred_scale_record *record);

void swl_test_scale_request_recording_begin(void);
void swl_test_scale_request_recording_end(void);
struct swl_test_viewport_destination_record
swl_test_scale_viewport_destination_record(void);
struct swl_test_scale_destroy_record swl_test_scale_destroy_record(void);

void swl_test_xdg_popup_listener_emit_configure(
    void *data,
    struct xdg_popup *popup,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height,
    struct swl_test_xdg_popup_configure_record *record);
void swl_test_xdg_popup_listener_emit_done(
    void *data,
    struct xdg_popup *popup,
    struct swl_test_xdg_popup_done_record *record);
void swl_test_xdg_popup_listener_emit_repositioned(
    void *data,
    struct xdg_popup *popup,
    uint32_t token,
    struct swl_test_xdg_popup_repositioned_record *record);

void swl_test_xdg_request_recording_begin(void);
void swl_test_xdg_request_recording_end(void);
struct swl_test_xdg_positioner_request_record
swl_test_xdg_positioner_request_record(void);
struct swl_test_xdg_popup_grab_record swl_test_xdg_popup_grab_record(void);
struct swl_test_xdg_destroy_record swl_test_xdg_destroy_record(void);
#endif

#ifdef __cplusplus
}
#endif
