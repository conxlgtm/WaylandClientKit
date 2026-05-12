#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROTOCOL_HEADER="$ROOT/Sources/CWaylandProtocols/include/swift-wayland-shims.h"
PROTOCOL_SHIMS_DIR="$ROOT/Sources/CWaylandProtocols/shims"
RUNTIME_HEADER="$ROOT/Sources/CWaylandRuntimeShims/include/swift-wayland-runtime-shims.h"
RUNTIME_SHIMS_DIR="$ROOT/Sources/CWaylandRuntimeShims"
CURSOR_HEADER="$ROOT/Sources/CWaylandCursorShims/include/swift-wayland-cursor-shims.h"
CURSOR_SHIMS_DIR="$ROOT/Sources/CWaylandCursorShims"

protocol_symbols=(
    swl_display_get_registry
    swl_display_sync
    swl_display_create_event_queue
    swl_event_queue_destroy
    swl_display_create_wrapper
    swl_display_wrapper_set_queue
    swl_display_wrapper_destroy
    swl_display_dispatch_event_queue_pending
    swl_display_prepare_read_event_queue
    swl_display_get_protocol_error_details
    swl_registry_bind_wl_compositor
    swl_registry_bind_wl_shm
    swl_registry_bind_xdg_wm_base
    swl_registry_bind_zxdg_decoration_manager_v1
    swl_registry_bind_zxdg_output_manager_v1
    swl_registry_bind_wp_viewporter
    swl_registry_bind_wp_presentation
    swl_registry_bind_wp_fractional_scale_manager_v1
    swl_registry_bind_wl_seat
    swl_registry_bind_zwp_linux_dmabuf_v1
    swl_registry_bind_zwp_primary_selection_device_manager_v1
    swl_registry_add_listener
    swl_callback_add_listener
    swl_buffer_add_listener
    swl_surface_add_listener
    swl_xdg_wm_base_add_listener
    swl_xdg_surface_add_listener
    swl_xdg_toplevel_add_listener
    swl_zxdg_toplevel_decoration_v1_add_listener
    swl_wp_fractional_scale_v1_add_listener
    swl_seat_add_listener
    swl_pointer_add_listener
    swl_keyboard_add_listener
    swl_touch_add_listener
    swl_primary_selection_offer_add_listener
    swl_primary_selection_source_add_listener
    swl_primary_selection_device_add_listener
    swl_pointer_set_cursor
    swl_primary_selection_device_manager_create_source
    swl_primary_selection_device_manager_get_device
    swl_primary_selection_source_offer
    swl_primary_selection_offer_receive
    swl_primary_selection_device_set_selection
    swl_primary_selection_offer_destroy
    swl_primary_selection_source_destroy
    swl_primary_selection_device_destroy
    swl_primary_selection_device_manager_destroy
    swl_shm_format_xrgb8888
    swl_shm_format_argb8888
    swl_proxy_get_version
    swl_proxy_get_id
    swl_proxy_get_queue_raw
    swl_zxdg_decoration_manager_v1_get_toplevel_decoration
    swl_zxdg_output_manager_v1_get_xdg_output
    swl_zxdg_toplevel_decoration_v1_set_mode
    swl_zxdg_toplevel_decoration_v1_unset_mode
    swl_zxdg_toplevel_decoration_v1_mode_client_side
    swl_zxdg_toplevel_decoration_v1_mode_server_side
    swl_zxdg_toplevel_decoration_v1_destroy
    swl_zxdg_decoration_manager_v1_destroy
    swl_zxdg_output_v1_destroy
    swl_zxdg_output_manager_v1_destroy
    swl_zxdg_output_v1_add_listener
    swl_wp_viewporter_get_viewport
    swl_wp_viewport_set_destination
    swl_wp_viewport_destroy
    swl_wp_viewporter_destroy
    swl_wp_presentation_feedback
    swl_wp_presentation_destroy
    swl_wp_presentation_feedback_destroy
    swl_wp_presentation_add_listener
    swl_wp_presentation_feedback_add_listener
    swl_zwp_linux_dmabuf_v1_destroy
    swl_zwp_linux_dmabuf_v1_get_default_feedback
    swl_zwp_linux_dmabuf_v1_get_surface_feedback
    swl_zwp_linux_dmabuf_feedback_v1_destroy
    swl_zwp_linux_dmabuf_feedback_v1_add_listener
    swl_wp_fractional_scale_manager_v1_get_fractional_scale
    swl_wp_fractional_scale_v1_destroy
    swl_wp_fractional_scale_manager_v1_destroy
    swl_surface_set_buffer_scale
)

cursor_symbols=(
    swl_cursor_theme_load
    swl_cursor_theme_destroy
    swl_cursor_theme_get_cursor
    swl_cursor_image_count
    swl_cursor_image_at
    swl_cursor_image_width
    swl_cursor_image_height
    swl_cursor_image_hotspot_x
    swl_cursor_image_hotspot_y
    swl_cursor_image_delay
    swl_cursor_image_get_buffer
)

runtime_symbols=(
    swl_eventfd
    swl_efd_cloexec
    swl_efd_nonblock
    swl_memfd_create
    swl_mfd_cloexec
    swl_pipe_cloexec
    swl_write_no_sigpipe
)

missing=0
check_symbol_group() {
    local header="$1"
    local implementation_dir="$2"
    shift 2

    local symbol
    for symbol in "$@"; do
        if ! rg --quiet "\\b${symbol}\\b" "$header"; then
            echo "Missing shim declaration: $symbol"
            missing=1
        fi

        if ! rg --quiet "\\b${symbol}\\b" "$implementation_dir"; then
            echo "Missing shim implementation: $symbol"
            missing=1
        fi
    done
}

if [[ ! -f "$PROTOCOL_HEADER" ]]; then
    echo "Missing protocol shim header: $PROTOCOL_HEADER"
    missing=1
fi

if [[ ! -d "$PROTOCOL_SHIMS_DIR" ]]; then
    echo "Missing protocol shim implementation directory: $PROTOCOL_SHIMS_DIR"
    missing=1
fi

if [[ ! -f "$CURSOR_HEADER" ]]; then
    echo "Missing cursor shim header: $CURSOR_HEADER"
    missing=1
fi

if [[ ! -f "$RUNTIME_HEADER" ]]; then
    echo "Missing runtime shim header: $RUNTIME_HEADER"
    missing=1
fi

if [[ ! -d "$CURSOR_SHIMS_DIR" ]]; then
    echo "Missing cursor shim implementation directory: $CURSOR_SHIMS_DIR"
    missing=1
fi

if [[ ! -d "$RUNTIME_SHIMS_DIR" ]]; then
    echo "Missing runtime shim implementation directory: $RUNTIME_SHIMS_DIR"
    missing=1
fi

if [[ "$missing" -eq 0 ]]; then
    check_symbol_group "$PROTOCOL_HEADER" "$PROTOCOL_SHIMS_DIR" "${protocol_symbols[@]}"
    check_symbol_group "$CURSOR_HEADER" "$CURSOR_SHIMS_DIR" "${cursor_symbols[@]}"
    check_symbol_group "$RUNTIME_HEADER" "$RUNTIME_SHIMS_DIR" "${runtime_symbols[@]}"
fi

exit "$missing"
