#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEADER="$ROOT/Sources/CWaylandProtocols/include/swift-wayland-shims.h"
SHIMS_DIR="$ROOT/Sources/CWaylandProtocols/shims"

required_symbols=(
    swl_registry_bind_wl_compositor
    swl_registry_bind_wl_shm
    swl_registry_bind_xdg_wm_base
    swl_registry_bind_wl_seat
    swl_registry_add_listener
    swl_callback_add_listener
    swl_buffer_add_listener
    swl_xdg_wm_base_add_listener
    swl_xdg_surface_add_listener
    swl_xdg_toplevel_add_listener
    swl_seat_add_listener
    swl_pointer_add_listener
    swl_keyboard_add_listener
    swl_touch_add_listener
    swl_pointer_set_cursor
    swl_proxy_get_version
    swl_proxy_get_id
)

missing=0
for symbol in "${required_symbols[@]}"; do
    if ! rg --quiet "\\b${symbol}\\b" "$HEADER"; then
        echo "Missing shim declaration: $symbol"
        missing=1
    fi

    if ! rg --quiet "\\b${symbol}\\b" "$SHIMS_DIR"; then
        echo "Missing shim implementation: $symbol"
        missing=1
    fi
done

exit "$missing"
