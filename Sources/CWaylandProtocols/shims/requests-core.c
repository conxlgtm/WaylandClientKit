#include "swift-wayland-shims.h"
#include "generated/wayland-client-protocol.h"

#include <sys/mman.h>

#ifndef MFD_CLOEXEC
#define MFD_CLOEXEC 0x0001U
#endif

struct wl_surface *swl_compositor_create_surface(struct wl_compositor *compositor)
{
    return wl_compositor_create_surface(compositor);
}

struct wl_shm_pool *swl_shm_create_pool(struct wl_shm *shm, int32_t fd, int32_t size)
{
    return wl_shm_create_pool(shm, fd, size);
}

struct wl_buffer *swl_shm_pool_create_buffer(
    struct wl_shm_pool *pool, int32_t offset, int32_t width,
    int32_t height, int32_t stride, uint32_t format)
{
    return wl_shm_pool_create_buffer(pool, offset, width, height, stride, format);
}

struct wl_callback *swl_surface_frame(struct wl_surface *surface)
{
    return wl_surface_frame(surface);
}

void swl_surface_attach(
    struct wl_surface *surface, struct wl_buffer *buffer, int32_t x, int32_t y)
{
    wl_surface_attach(surface, buffer, x, y);
}

void swl_surface_commit(struct wl_surface *surface)
{
    wl_surface_commit(surface);
}

void swl_surface_damage(
    struct wl_surface *surface, int32_t x, int32_t y,
    int32_t width, int32_t height)
    {
        wl_surface_damage(surface, x, y, width, height);
    }

uint32_t swl_shm_format_xrgb8888(void)
{
    return WL_SHM_FORMAT_XRGB8888;
}

int swl_memfd_create(const char *name, unsigned int flags)
{
    return memfd_create(name, flags);
}

unsigned int swl_mfd_cloexec(void)
{
    return MFD_CLOEXEC;
}

void swl_surface_damage_buffer(
    struct wl_surface *surface, int32_t x, int32_t y,
    int32_t width, int32_t height)
{
    wl_surface_damage_buffer(surface, x, y, width, height);
}

struct wl_pointer *swl_seat_get_pointer(struct wl_seat *seat)
{
    return wl_seat_get_pointer(seat);
}

struct wl_keyboard *swl_seat_get_keyboard(struct wl_seat *seat)
{
    return wl_seat_get_keyboard(seat);
}

struct wl_touch *swl_seat_get_touch(struct wl_seat *seat)
{
    return wl_seat_get_touch(seat);
}

void swl_pointer_set_cursor(
    struct wl_pointer *pointer,
    uint32_t serial,
    struct wl_surface *surface,
    int32_t hotspot_x,
    int32_t hotspot_y)
{
    wl_pointer_set_cursor(pointer, serial, surface, hotspot_x, hotspot_y);
}

uint32_t swl_proxy_get_version(void *proxy)
{
    return wl_proxy_get_version((struct wl_proxy *)proxy);
}

uint32_t swl_proxy_get_id(void *proxy)
{
    return wl_proxy_get_id((struct wl_proxy *)proxy);
}

void swl_registry_destroy(struct wl_registry *registry)
{
    wl_registry_destroy(registry);
}

void swl_callback_destroy(struct wl_callback *callback)
{
    wl_callback_destroy(callback);
}

void swl_compositor_destroy(struct wl_compositor *compositor)
{
    wl_compositor_destroy(compositor);
}

void swl_shm_destroy(struct wl_shm *shm)
{
    wl_shm_destroy(shm);
}

void swl_buffer_destroy(struct wl_buffer *buffer)
{
    wl_buffer_destroy(buffer);
}

void swl_surface_destroy(struct wl_surface *surface)
{
    wl_surface_destroy(surface);
}

void swl_shm_pool_destroy(struct wl_shm_pool *pool)
{
    wl_shm_pool_destroy(pool);
}

void swl_pointer_release(struct wl_pointer *pointer)
{
    wl_pointer_release(pointer);
}

void swl_keyboard_release(struct wl_keyboard *keyboard)
{
    wl_keyboard_release(keyboard);
}

void swl_touch_release(struct wl_touch *touch)
{
    wl_touch_release(touch);
}

void swl_seat_destroy(struct wl_seat *seat)
{
    wl_seat_destroy(seat);
}

void swl_seat_release(struct wl_seat *seat)
{
    wl_seat_release(seat);
}
