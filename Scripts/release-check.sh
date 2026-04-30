#!/usr/bin/env bash
set -euo pipefail

make check
./Scripts/swift.sh build --disable-index-store -c release
./Scripts/swift.sh build --disable-index-store -c release --product swift-wayland-demo
./Scripts/swift.sh build --disable-index-store -c release --product swift-wayland-smoke

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    ./Scripts/smoke-wayland.sh
elif [[ "${CI:-}" == "true" || "${REQUIRE_WAYLAND_SMOKE:-}" == "1" ]]; then
    echo "Live Wayland smoke check is required, but WAYLAND_DISPLAY is not set." >&2
    exit 1
else
    echo "Skipping live Wayland smoke check because WAYLAND_DISPLAY is not set."
fi
