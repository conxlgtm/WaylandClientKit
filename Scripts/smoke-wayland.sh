#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "WAYLAND_DISPLAY is not set; run this under a Wayland session."
    exit 1
fi

PROCESS_TIMEOUT_SECONDS="${SWIFT_WAYLAND_SMOKE_PROCESS_TIMEOUT_SECONDS:-60}"
CONFIGURE_TIMEOUT_MILLISECONDS="${SWIFT_WAYLAND_SMOKE_CONFIGURE_TIMEOUT_MILLISECONDS:-5000}"

timeout "${PROCESS_TIMEOUT_SECONDS}s" \
    ./Scripts/swift.sh run --disable-index-store swift-wayland-smoke -- \
    --timeout-milliseconds "${CONFIGURE_TIMEOUT_MILLISECONDS}"
