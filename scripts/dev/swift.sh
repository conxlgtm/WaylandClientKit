#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/swift-runtime-env.sh"

swift_wayland_run_swift() {
    local swift_binary="$1"
    shift

    if [[ "${SWIFT_WAYLAND_SHOW_COMPAT_WARNINGS:-0}" == "1" ]]; then
        exec "${swift_binary}" "$@"
    fi

    "${swift_binary}" "$@" 2> >(
        grep \
            --invert-match \
            --fixed-strings \
            "libxml2.so.2: no version information available" \
            >&2
    )
    exit "$?"
}

if [[ -n "${SWIFT_BIN:-}" ]]; then
    swift_wayland_run_swift "${SWIFT_BIN}" "$@"
fi

SWIFTLY_HOME_DIR="${SWIFTLY_HOME:-$HOME/.local/share/swiftly}"
SWIFTLY_TOOLCHAIN_SWIFT=""
if [[ -d "${SWIFTLY_HOME_DIR}/toolchains" ]]; then
    SWIFTLY_TOOLCHAIN_SWIFT="$(
        find "${SWIFTLY_HOME_DIR}/toolchains" -path '*/usr/bin/swift' \
            | sort \
            | tail -n 1
    )"
fi

if [[ -n "${SWIFTLY_TOOLCHAIN_SWIFT}" ]]; then
    swift_wayland_run_swift "${SWIFTLY_TOOLCHAIN_SWIFT}" "$@"
fi

swift_wayland_run_swift swift "$@"
