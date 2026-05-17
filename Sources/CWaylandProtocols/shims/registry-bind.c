#include "swift-wayland-shims.h"
#include "generated/staging/fractional-scale/fractional-scale-v1-client-protocol.h"
#include "generated/staging/cursor-shape/cursor-shape-v1-client-protocol.h"
#include "generated/core/wayland-client-protocol.h"
#include "generated/stable/presentation-time/presentation-time-client-protocol.h"
#include "generated/stable/viewporter/viewporter-client-protocol.h"
#include "generated/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/text-input/text-input-unstable-v3-client-protocol.h"
#include "generated/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/xdg-output/xdg-output-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/primary-selection/primary-selection-unstable-v1-client-protocol.h"
#include "generated/stable/xdg-shell/xdg-shell-client-protocol.h"

struct wl_compositor *swl_registry_bind_wl_compositor(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wl_compositor *)wl_registry_bind(
        registry, name, &wl_compositor_interface, version);
}

struct wl_shm *swl_registry_bind_wl_shm(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wl_shm *)wl_registry_bind(
        registry, name, &wl_shm_interface, version);
}

struct wl_output *swl_registry_bind_wl_output(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wl_output *)wl_registry_bind(
        registry, name, &wl_output_interface, version);
}

struct xdg_wm_base *swl_registry_bind_xdg_wm_base(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct xdg_wm_base *)wl_registry_bind(
        registry, name, &xdg_wm_base_interface, version);
}

struct zxdg_decoration_manager_v1 *swl_registry_bind_zxdg_decoration_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zxdg_decoration_manager_v1 *)wl_registry_bind(
        registry, name, &zxdg_decoration_manager_v1_interface, version);
}

struct zxdg_output_manager_v1 *swl_registry_bind_zxdg_output_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zxdg_output_manager_v1 *)wl_registry_bind(
        registry, name, &zxdg_output_manager_v1_interface, version);
}

struct wp_viewporter *swl_registry_bind_wp_viewporter(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_viewporter *)wl_registry_bind(
        registry, name, &wp_viewporter_interface, version);
}

struct wp_presentation *swl_registry_bind_wp_presentation(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_presentation *)wl_registry_bind(
        registry, name, &wp_presentation_interface, version);
}

struct wp_fractional_scale_manager_v1 *swl_registry_bind_wp_fractional_scale_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_fractional_scale_manager_v1 *)wl_registry_bind(
        registry, name, &wp_fractional_scale_manager_v1_interface, version);
}

struct wp_cursor_shape_manager_v1 *swl_registry_bind_wp_cursor_shape_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_cursor_shape_manager_v1 *)wl_registry_bind(
        registry, name, &wp_cursor_shape_manager_v1_interface, version);
}

struct wl_seat *swl_registry_bind_wl_seat(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wl_seat *)wl_registry_bind(
        registry, name, &wl_seat_interface, version);
}

struct wl_data_device_manager *swl_registry_bind_wl_data_device_manager(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wl_data_device_manager *)wl_registry_bind(
        registry, name, &wl_data_device_manager_interface, version);
}

struct zwp_primary_selection_device_manager_v1 *
swl_registry_bind_zwp_primary_selection_device_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zwp_primary_selection_device_manager_v1 *)wl_registry_bind(
        registry,
        name,
        &zwp_primary_selection_device_manager_v1_interface,
        version);
}

struct zwp_text_input_manager_v3 *swl_registry_bind_zwp_text_input_manager_v3(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zwp_text_input_manager_v3 *)wl_registry_bind(
        registry, name, &zwp_text_input_manager_v3_interface, version);
}

struct zwp_linux_dmabuf_v1 *swl_registry_bind_zwp_linux_dmabuf_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zwp_linux_dmabuf_v1 *)wl_registry_bind(
        registry, name, &zwp_linux_dmabuf_v1_interface, version);
}
