#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "WAYLAND_DISPLAY is not set. Run GPU preview tests under a Wayland session."
    exit 1
fi

PROCESS_TIMEOUT_SECONDS="${SWIFT_WAYLAND_GPU_PREVIEW_TIMEOUT_SECONDS:-240}"

env \
    SWL_RUN_GPU_SMOKE=1 \
    SWIFT_WAYLAND_ENABLE_GPU_PREVIEW_TESTS=1 \
    timeout "${PROCESS_TIMEOUT_SECONDS}s" \
    "$ROOT/scripts/dev/swift.sh" test \
    --filter 'GPUPreviewLiveCapability|gpuSmokeDrawsDeterministicPixelWhenEnabled'
