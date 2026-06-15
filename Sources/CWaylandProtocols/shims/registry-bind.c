#include "wayland-client-kit-shims.h"
#include "generated/staging/fractional-scale/fractional-scale-v1-client-protocol.h"
#include "generated/staging/cursor-shape/cursor-shape-v1-client-protocol.h"
#include "generated/staging/pointer-warp/pointer-warp-v1-client-protocol.h"
#include "generated/stable/tablet/tablet-v2-client-protocol.h"
#include "generated/staging/xdg-activation/xdg-activation-v1-client-protocol.h"
#include "generated/staging/xdg-session-management/xdg-session-management-v1-client-protocol.h"
#include "generated/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1-client-protocol.h"
#include "generated/staging/xdg-system-bell/xdg-system-bell-v1-client-protocol.h"
#include "generated/staging/xdg-dialog/xdg-dialog-v1-client-protocol.h"
#include "generated/staging/xdg-toplevel-drag/xdg-toplevel-drag-v1-client-protocol.h"
#include "generated/staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1-client-protocol.h"
#include "generated/legacy-unstable/relative-pointer/relative-pointer-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/pointer-gestures/pointer-gestures-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1-client-protocol.h"
#include "generated/legacy-unstable/idle-inhibit/idle-inhibit-unstable-v1-client-protocol.h"
#include "generated/wlr-unstable/output-management/wlr-output-management-unstable-v1-client-protocol.h"
#include "generated/staging/linux-drm-syncobj/linux-drm-syncobj-v1-client-protocol.h"
#include "generated/staging/fifo/fifo-v1-client-protocol.h"
#include "generated/staging/commit-timing/commit-timing-v1-client-protocol.h"
#include "generated/staging/content-type/content-type-v1-client-protocol.h"
#include "generated/staging/alpha-modifier/alpha-modifier-v1-client-protocol.h"
#include "generated/staging/tearing-control/tearing-control-v1-client-protocol.h"
#include "generated/staging/color-representation/color-representation-v1-client-protocol.h"
#include "generated/staging/color-management/color-management-v1-client-protocol.h"
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

struct wl_subcompositor *swl_registry_bind_wl_subcompositor(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wl_subcompositor *)wl_registry_bind(
        registry, name, &wl_subcompositor_interface, version);
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

struct xdg_activation_v1 *swl_registry_bind_xdg_activation_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct xdg_activation_v1 *)wl_registry_bind(
        registry, name, &xdg_activation_v1_interface, version);
}

struct xdg_session_manager_v1 *swl_registry_bind_xdg_session_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct xdg_session_manager_v1 *)wl_registry_bind(
        registry, name, &xdg_session_manager_v1_interface, version);
}

struct xdg_toplevel_icon_manager_v1 *
swl_registry_bind_xdg_toplevel_icon_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct xdg_toplevel_icon_manager_v1 *)wl_registry_bind(
        registry, name, &xdg_toplevel_icon_manager_v1_interface, version);
}

struct xdg_system_bell_v1 *swl_registry_bind_xdg_system_bell_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct xdg_system_bell_v1 *)wl_registry_bind(
        registry, name, &xdg_system_bell_v1_interface, version);
}

struct xdg_wm_dialog_v1 *swl_registry_bind_xdg_wm_dialog_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct xdg_wm_dialog_v1 *)wl_registry_bind(
        registry, name, &xdg_wm_dialog_v1_interface, version);
}

struct xdg_toplevel_drag_manager_v1 *
swl_registry_bind_xdg_toplevel_drag_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct xdg_toplevel_drag_manager_v1 *)wl_registry_bind(
        registry, name, &xdg_toplevel_drag_manager_v1_interface, version);
}

struct ext_foreign_toplevel_list_v1 *
swl_registry_bind_ext_foreign_toplevel_list_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct ext_foreign_toplevel_list_v1 *)wl_registry_bind(
        registry, name, &ext_foreign_toplevel_list_v1_interface, version);
}

struct wp_pointer_warp_v1 *swl_registry_bind_wp_pointer_warp_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_pointer_warp_v1 *)wl_registry_bind(
        registry, name, &wp_pointer_warp_v1_interface, version);
}

struct zwp_tablet_manager_v2 *swl_registry_bind_zwp_tablet_manager_v2(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zwp_tablet_manager_v2 *)wl_registry_bind(
        registry, name, &zwp_tablet_manager_v2_interface, version);
}

struct zwp_relative_pointer_manager_v1 *
swl_registry_bind_zwp_relative_pointer_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zwp_relative_pointer_manager_v1 *)wl_registry_bind(
        registry, name, &zwp_relative_pointer_manager_v1_interface, version);
}

struct zwp_pointer_constraints_v1 *
swl_registry_bind_zwp_pointer_constraints_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zwp_pointer_constraints_v1 *)wl_registry_bind(
        registry, name, &zwp_pointer_constraints_v1_interface, version);
}

struct zwp_pointer_gestures_v1 *
swl_registry_bind_zwp_pointer_gestures_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zwp_pointer_gestures_v1 *)wl_registry_bind(
        registry, name, &zwp_pointer_gestures_v1_interface, version);
}

struct zwp_keyboard_shortcuts_inhibit_manager_v1 *
swl_registry_bind_zwp_keyboard_shortcuts_inhibit_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zwp_keyboard_shortcuts_inhibit_manager_v1 *)wl_registry_bind(
        registry, name, &zwp_keyboard_shortcuts_inhibit_manager_v1_interface, version);
}

struct zwp_idle_inhibit_manager_v1 *
swl_registry_bind_zwp_idle_inhibit_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zwp_idle_inhibit_manager_v1 *)wl_registry_bind(
        registry, name, &zwp_idle_inhibit_manager_v1_interface, version);
}

struct wp_linux_drm_syncobj_manager_v1 *
swl_registry_bind_wp_linux_drm_syncobj_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_linux_drm_syncobj_manager_v1 *)wl_registry_bind(
        registry, name, &wp_linux_drm_syncobj_manager_v1_interface, version);
}

struct wp_fifo_manager_v1 *swl_registry_bind_wp_fifo_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_fifo_manager_v1 *)wl_registry_bind(
        registry, name, &wp_fifo_manager_v1_interface, version);
}

struct wp_commit_timing_manager_v1 *swl_registry_bind_wp_commit_timing_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_commit_timing_manager_v1 *)wl_registry_bind(
        registry, name, &wp_commit_timing_manager_v1_interface, version);
}

struct wp_content_type_manager_v1 *swl_registry_bind_wp_content_type_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_content_type_manager_v1 *)wl_registry_bind(
        registry, name, &wp_content_type_manager_v1_interface, version);
}

struct wp_alpha_modifier_v1 *swl_registry_bind_wp_alpha_modifier_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_alpha_modifier_v1 *)wl_registry_bind(
        registry, name, &wp_alpha_modifier_v1_interface, version);
}

struct wp_tearing_control_manager_v1 *
swl_registry_bind_wp_tearing_control_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_tearing_control_manager_v1 *)wl_registry_bind(
        registry, name, &wp_tearing_control_manager_v1_interface, version);
}

struct wp_color_representation_manager_v1 *
swl_registry_bind_wp_color_representation_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_color_representation_manager_v1 *)wl_registry_bind(
        registry, name, &wp_color_representation_manager_v1_interface, version);
}

struct wp_color_manager_v1 *swl_registry_bind_wp_color_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct wp_color_manager_v1 *)wl_registry_bind(
        registry, name, &wp_color_manager_v1_interface, version);
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

struct zwlr_output_manager_v1 *swl_registry_bind_zwlr_output_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version)
{
    return (struct zwlr_output_manager_v1 *)wl_registry_bind(
        registry, name, &zwlr_output_manager_v1_interface, version);
}
