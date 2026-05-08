#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -z "${WAYLAND_DISPLAY:-}" ]]
then
    echo "WAYLAND_DISPLAY is not set. Run public integration tests under a Wayland session."
    exit 1
fi

PROCESS_TIMEOUT_SECONDS="${SWIFT_WAYLAND_INTEGRATION_PROCESS_TIMEOUT_SECONDS:-90}"

export SWIFT_WAYLAND_ENABLE_PUBLIC_INTEGRATION_TESTS=1

timeout "${PROCESS_TIMEOUT_SECONDS}s" \
    env CC="${REPO_ROOT}/Scripts/clang-filter-index-store.sh" \
        "${REPO_ROOT}/Scripts/swift.sh" test \
        --package-path "${REPO_ROOT}/IntegrationTests/PublicAPIClient" \
        --filter WaylandDisplayPublicIntegrationTests
