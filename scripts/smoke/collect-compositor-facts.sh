#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

include_smoke=0

usage() {
    cat <<'USAGE'
usage: scripts/smoke/collect-compositor-facts.sh [--include-smoke]

Print Markdown facts for the current Wayland compositor session.

Options:
  --include-smoke  Run scripts/smoke/smoke-wayland.sh after printing facts.
  -h, --help       Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --include-smoke)
            include_smoke=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

print_command_value() {
    local label="$1"
    shift

    if output="$("$@" 2>/dev/null)"; then
        printf -- '- %s: `%s`\n' "$label" "$output"
    else
        printf -- '- %s: unavailable\n' "$label"
    fi
}

print_pkg_config_version() {
    local package="$1"

    if output="$(pkg-config --modversion "$package" 2>/dev/null)"; then
        printf -- '- %s: `%s`\n' "$package" "$output"
    else
        printf -- '- %s: unavailable\n' "$package"
    fi
}

print_wayland_globals() {
    local probe="$1"
    local output

    echo '```text'
    if output="$(timeout 10 "$probe" 2>/dev/null)"; then
        printf '%s\n' "$output"
        WAYLAND_GLOBALS_TEXT="$output"
    else
        local status="$?"

        if [[ "$status" -eq 124 ]]; then
            printf '%s timed out after 10 seconds.\n' "$probe"
        else
            printf '%s failed with exit status %s.\n' "$probe" "$status"
        fi
    fi
    echo '```'
}

print_protocol_summary() {
    local globals="$1"
    local protocol
    local protocols=(
        wl_compositor
        wl_shm
        wl_seat
        xdg_wm_base
        wp_viewporter
        wp_fractional_scale_manager_v1
        wp_presentation
        zwp_linux_dmabuf_v1
        wp_linux_drm_syncobj_manager_v1
        wp_fifo_manager_v1
        wp_commit_timing_manager_v1
        wl_data_device_manager
        zwp_primary_selection_device_manager_v1
        wp_cursor_shape_manager_v1
        zwp_text_input_manager_v3
        zxdg_decoration_manager_v1
        zxdg_output_manager_v1
    )

    echo "## Protocol Summary"
    echo
    if [[ -z "$globals" ]]; then
        echo "Global protocol summary unavailable."
        return
    fi

    for protocol in "${protocols[@]}"; do
        if grep -Eq "(^|[^[:alnum:]_])${protocol}([^[:alnum:]_]|$)" <<<"$globals"; then
            printf -- '- %s: present\n' "$protocol"
        else
            printf -- '- %s: absent\n' "$protocol"
        fi
    done
}

WAYLAND_GLOBALS_TEXT=""

echo "# SwiftWayland Compositor Facts"
echo
print_command_value "Collected" date -u "+%Y-%m-%dT%H:%M:%SZ"
print_command_value "Kernel" uname -srmo
print_command_value "Swift" "$ROOT/scripts/dev/swift.sh" --version
echo "- WAYLAND_DISPLAY: \`${WAYLAND_DISPLAY:-unset}\`"
echo "- XDG_CURRENT_DESKTOP: \`${XDG_CURRENT_DESKTOP:-unset}\`"
echo "- DESKTOP_SESSION: \`${DESKTOP_SESSION:-unset}\`"
echo
echo "## System Libraries"
echo
print_pkg_config_version wayland-client
print_pkg_config_version wayland-protocols
print_pkg_config_version xkbcommon
print_pkg_config_version wayland-cursor
print_pkg_config_version libdrm
print_pkg_config_version gbm
print_pkg_config_version egl
print_pkg_config_version glesv2
echo
echo "## Wayland Globals"
echo

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "WAYLAND_DISPLAY is not set."
elif command -v wayland-info >/dev/null 2>&1; then
    print_wayland_globals wayland-info
elif command -v weston-info >/dev/null 2>&1; then
    print_wayland_globals weston-info
else
    echo "Install wayland-utils or weston-info to collect advertised globals."
fi

echo
print_protocol_summary "$WAYLAND_GLOBALS_TEXT"

if [[ "$include_smoke" -eq 1 ]]; then
    echo
    echo "## Smoke"
    echo
    echo '```text'
    "$ROOT/scripts/smoke/smoke-wayland.sh"
    echo '```'
fi
