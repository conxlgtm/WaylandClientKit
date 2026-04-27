#!/usr/bin/env bash
set -euo pipefail

make check
./Scripts/swift.sh build --disable-index-store -c release
./Scripts/swift.sh build --disable-index-store -c release --product swift-wayland-demo
./Scripts/swift.sh build --disable-index-store -c release --product swift-wayland-smoke

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    ./Scripts/smoke-wayland.sh
else
    echo "Skipping live Wayland smoke check because WAYLAND_DISPLAY is not set."
fi
