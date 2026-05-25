#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

SWIFT_WAYLAND_ENABLE_PUBLIC_INTEGRATION_TESTS=0 make check-base
./scripts/dev/swift.sh build --disable-index-store -c release
./scripts/dev/swift.sh build --disable-index-store -c release --target SwiftWaylandDemo
./scripts/dev/swift.sh build --disable-index-store -c release --target GPUPreviewSmokeClient
./scripts/dev/swift.sh build --disable-index-store -c release --product swift-wayland-smoke
./scripts/ci/test-framework-handoff-examples.sh
make test-release
./scripts/shims/verify-release-shim-symbols.sh

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    ./scripts/smoke/smoke-wayland.sh
    ./scripts/smoke/integration-wayland.sh
elif command -v weston >/dev/null 2>&1; then
    make wayland-headless
elif [[ "${CI:-}" == "true" || "${REQUIRE_WAYLAND_SMOKE:-}" == "1" ]]; then
    echo "Live Wayland smoke and public integration checks are required, but WAYLAND_DISPLAY is not set." >&2
    exit 1
else
    echo "Skipping live Wayland smoke and public integration checks because WAYLAND_DISPLAY is not set."
fi
