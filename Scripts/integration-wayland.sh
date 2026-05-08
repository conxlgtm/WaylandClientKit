#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${WAYLAND_DISPLAY:-}" ]]
then
    echo "WAYLAND_DISPLAY is not set. Run public integration tests under a Wayland session."
    exit 1
fi

PROCESS_TIMEOUT_SECONDS="${SWIFT_WAYLAND_INTEGRATION_PROCESS_TIMEOUT_SECONDS:-90}"

export SWIFT_WAYLAND_ENABLE_PUBLIC_INTEGRATION_TESTS=1

timeout "${PROCESS_TIMEOUT_SECONDS}s" \
    ./Scripts/swift.sh test --filter WaylandDisplayPublicIntegrationTests
