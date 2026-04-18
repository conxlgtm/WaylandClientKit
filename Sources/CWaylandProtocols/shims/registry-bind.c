#include "wayforge-shims.h"
#include "generated/wayland-client-protocol.h"
#include "generated/xdg-shell-client-protocol.h"

struct wl_compositor *swl_registry_bind_wl_compositor(
    struct wl_registry *registry,
    uint32_t name,
    uint32_t version)
{
    return (struct wl_compositor *)wl_registry_bind(
        registry,
        name,
        &wl_compositor_interface,
        version);
}
struct wl_shm *swl_registry_bind_wl_shm(
    struct wl_registry *registry,
    uint32_t name,
    uint32_t version)
{
    return (struct wl_shm *)wl_registry_bind(
        registry,
        name,
        &wl_shm_interface,
        version);
}
struct xdg_wm_base *swl_registry_bind_xdg_wm_base(
    struct wl_registry *registry,
    uint32_t name,
    uint32_t version)
{
    return (struct xdg_wm_base *)wl_registry_bind(
        registry,
        name,
        &xdg_wm_base_interface,
        version);
}
struct wl_seat *swl_registry_bind_wl_seat(
    struct wl_registry *registry,
    uint32_t name,
    uint32_t version)
{
    return (struct wl_seat *)wl_registry_bind(
        registry,
        name,
        &wl_seat_interface,
        version);
}
