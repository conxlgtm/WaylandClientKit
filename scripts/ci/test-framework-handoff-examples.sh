#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TARGETS=(
    ClientSideResizeChrome
    TextInputSmoke
    DataTransferSmoke
    TwoWindowFrameworkHost
    PresentationFeedbackAnimation
    SerialActionsProbe
    TwoWindowOrderStress
    FrameworkHostSmoke
    GPUPreviewSmokeClient
)

BUILD_ROOT="${BUILD_ROOT:-${TMPDIR:-/tmp}/swiftwayland-framework-handoff-examples}"
SWIFT="${SWIFT:-${ROOT}/scripts/dev/swift.sh}"

for configuration in debug release; do
    for target in "${TARGETS[@]}"; do
        echo "Building ${target} (${configuration})"
        "${SWIFT}" build \
            --disable-index-store \
            --build-path "${BUILD_ROOT}/${configuration}" \
            -c "${configuration}" \
            --target "${target}"
    done
done
