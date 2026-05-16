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

    echo '```text'
    if timeout 10 "$probe"; then
        :
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

if [[ "$include_smoke" -eq 1 ]]; then
    echo
    echo "## Smoke"
    echo
    echo '```text'
    "$ROOT/scripts/smoke/smoke-wayland.sh"
    echo '```'
fi
