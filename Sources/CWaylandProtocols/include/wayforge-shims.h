#pragma once

#include <stdint.h>
#include <wayland-client.h>

struct xdg_wm_base;
struct xdg_surface;
struct xdg_toplevel;

#ifdef __cplusplus
extern "C" {
#endif
/*
 * Registry bind wrappers
 */
struct wl_compositor *swl_registry_bind_wl_compositor(
    struct wl_registry *registry,
    uint32_t name,
    uint32_t version);
struct wl_shm *swl_registry_bind_wl_shm(
    struct wl_registry *registry,
    uint32_t name,
    uint32_t version);
struct xdg_wm_base *swl_registry_bind_xdg_wm_base(
    struct wl_registry *registry,
    uint32_t name,
    uint32_t version);
struct wl_seat *swl_registry_bind_wl_seat(
    struct wl_registry *registry,
    uint32_t name,
    uint32_t version);

/*
 * Core request wrappers
 */
struct wl_surface *swl_compositor_create_surface(
    struct wl_compositor *compositor);
struct wl_shm_pool *swl_shm_create_pool(
    struct wl_shm *shm,
    int32_t fd,
    int32_t size);
struct wl_buffer *swl_shm_pool_create_buffer(
    struct wl_shm_pool *pool,
    int32_t offset,
    int32_t width,
    int32_t height,
    int32_t stride,
    uint32_t format);
struct wl_callback *swl_surface_frame(struct wl_surface *surface);
struct wl_pointer *swl_seat_get_pointer(struct wl_seat *seat);
struct wl_keyboard *swl_seat_get_keyboard(struct wl_seat *seat);

/*
 * xdg request wrappers
 */
struct xdg_surface *swl_xdg_wm_base_get_xdg_surface(
    struct xdg_wm_base *wm_base,
    struct wl_surface *surface);
struct xdg_toplevel *swl_xdg_surface_get_toplevel(
    struct xdg_surface *xdg_surface);
void swl_xdg_wm_base_pong(
    struct xdg_wm_base *wm_base,
    uint32_t serial);
void swl_xdg_surface_ack_configure(
    struct xdg_surface *xdg_surface,
    uint32_t serial);
void swl_xdg_toplevel_set_title(
    struct xdg_toplevel *xdg_toplevel,
    const char *title);
void swl_xdg_toplevel_set_app_id(
    struct xdg_toplevel *xdg_toplevel,
    const char *app_id);

/*
 * destroy / release wrappers
 */
void swl_callback_destroy(struct wl_callback *callback);
void swl_buffer_destroy(struct wl_buffer *buffer);
void swl_surface_destroy(struct wl_surface *surface);
void swl_shm_pool_destroy(struct wl_shm_pool *pool);
void swl_pointer_release(struct wl_pointer *pointer);
void swl_keyboard_release(struct wl_keyboard *keyboard);
void swl_seat_release(struct wl_seat *seat);
void swl_xdg_surface_destroy(struct xdg_surface *xdg_surface);
void swl_xdg_toplevel_destroy(struct xdg_toplevel *xdg_toplevel);
void swl_xdg_wm_base_destroy(struct xdg_wm_base *wm_base);

/*
 * Listener callback typedefs
 */
typedef void (*swl_registry_global_fn)(
    void *data,
    struct wl_registry *registry,
    uint32_t name,
    const char *interface,
    uint32_t version);
typedef void (*swl_registry_global_remove_fn)(
    void *data,
    struct wl_registry *registry,
    uint32_t name);
typedef void (*swl_callback_done_fn)(
    void *data,
    struct wl_callback *callback,
    uint32_t callback_data);
typedef void (*swl_buffer_release_fn)(
    void *data,
    struct wl_buffer *buffer);
typedef void (*swl_xdg_wm_base_ping_fn)(
    void *data,
    struct xdg_wm_base *wm_base,
    uint32_t serial);
typedef void (*swl_xdg_surface_configure_fn)(
    void *data,
    struct xdg_surface *xdg_surface,
    uint32_t serial);
typedef void (*swl_xdg_toplevel_configure_fn)(
    void *data,
    struct xdg_toplevel *xdg_toplevel,
    int32_t width,
    int32_t height,
    struct wl_array *states);
typedef void (*swl_xdg_toplevel_close_fn)(
    void *data,
    struct xdg_toplevel *xdg_toplevel);
typedef void (*swl_xdg_toplevel_configure_bounds_fn)(
    void *data,
    struct xdg_toplevel *xdg_toplevel,
    int32_t width,
    int32_t height);
typedef void (*swl_xdg_toplevel_wm_capabilities_fn)(
    void *data,
    struct xdg_toplevel *xdg_toplevel,
    struct wl_array *capabilities);
typedef void (*swl_seat_capabilities_fn)(
    void *data,
    struct wl_seat *seat,
    uint32_t capabilities);
typedef void (*swl_seat_name_fn)(
    void *data,
    struct wl_seat *seat,
    const char *name);

/*
 * Callback bundle structs
 *
 * Swift (later) can allocate and own one of these, keep it alive,
 * and pass its address into the listener installer.
 */
struct swl_registry_listener_callbacks {
    swl_registry_global_fn global;
    swl_registry_global_remove_fn global_remove;
    void *data;
};

struct swl_callback_listener_callbacks {
    swl_callback_done_fn done;
    void *data;
};

struct swl_buffer_listener_callbacks {
    swl_buffer_release_fn release;
    void *data;
};

struct swl_xdg_wm_base_listener_callbacks {
    swl_xdg_wm_base_ping_fn ping;
    void *data;
};

struct swl_xdg_surface_listener_callbacks {
    swl_xdg_surface_configure_fn configure;
    void *data;
};

struct swl_xdg_toplevel_listener_callbacks {
    swl_xdg_toplevel_configure_fn configure;
    swl_xdg_toplevel_close_fn close;
    swl_xdg_toplevel_configure_bounds_fn configure_bounds;
    swl_xdg_toplevel_wm_capabilities_fn wm_capabilities;
    void *data;
};

struct swl_seat_listener_callbacks {
    swl_seat_capabilities_fn capabilities;
    swl_seat_name_fn name;
    void *data;
};

/*
 * Typed listener installers
 */
int swl_registry_add_listener(
    struct wl_registry *registry,
    const struct swl_registry_listener_callbacks *callbacks);
int swl_callback_add_listener(
    struct wl_callback *callback,
    const struct swl_callback_listener_callbacks *callbacks);
int swl_buffer_add_listener(
    struct wl_buffer *buffer,
    const struct swl_buffer_listener_callbacks *callbacks);
int swl_xdg_wm_base_add_listener(
    struct xdg_wm_base *wm_base,
    const struct swl_xdg_wm_base_listener_callbacks *callbacks);
int swl_xdg_surface_add_listener(
    struct xdg_surface *xdg_surface,
    const struct swl_xdg_surface_listener_callbacks *callbacks);
int swl_xdg_toplevel_add_listener(
    struct xdg_toplevel *xdg_toplevel,
    const struct swl_xdg_toplevel_listener_callbacks *callbacks);
int swl_seat_add_listener(
    struct wl_seat *seat,
    const struct swl_seat_listener_callbacks *callbacks);
#ifdef __cplusplus
}
#endif
