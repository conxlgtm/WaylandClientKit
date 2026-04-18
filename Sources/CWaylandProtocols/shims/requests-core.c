#include "wayforge-shims.h"

struct wl_surface *swl_compositor_create_surface(
    struct wl_compositor *compositor)
{
    return wl_compositor_create_surface(compositor);
}
struct wl_shm_pool *swl_shm_create_pool(
    struct wl_shm *shm,
    int32_t fd,
    int32_t size)
{
    return wl_shm_create_pool(shm, fd, size);
}
struct wl_buffer *swl_shm_pool_create_buffer(
    struct wl_shm_pool *pool,
    int32_t offset,
    int32_t width,
    int32_t height,
    int32_t stride,
    uint32_t format)
{
    return wl_shm_pool_create_buffer(
        pool,
        offset,
        width,
        height,
        stride,
        format);
}
struct wl_callback *swl_surface_frame(
    struct wl_surface *surface)
{
    return wl_surface_frame(surface);
}
struct wl_pointer *swl_seat_get_pointer(
    struct wl_seat *seat)
{
    return wl_seat_get_pointer(seat);
}
struct wl_keyboard *swl_seat_get_keyboard(
    struct wl_seat *seat)
{
    return wl_seat_get_keyboard(seat);
}
void swl_callback_destroy(struct wl_callback *callback)
{
    wl_callback_destroy(callback);
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
void swl_seat_release(struct wl_seat *seat)
{
    wl_seat_release(seat);
}
