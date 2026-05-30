#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TARGETS=(
    SurfaceRegionSmoke
    DamageRegionSmoke
    SubsurfaceSmoke
    CursorPolicySmoke
    CustomCursorSmoke
    WindowIconSmoke
    IdleInhibitSmoke
    SystemBellSmoke
    PointerCaptureSmoke
    XDGActivationSmoke
    TextInputSmoke
    DataTransferSmoke
    PresentationFeedbackAnimation
    FrameworkHostSmoke
    GPUPreviewSmokeClient
    GraphicsPreviewManagedGPUClear
)

BUILD_ROOT="${BUILD_ROOT:-${TMPDIR:-/tmp}/swiftwayland-examples-build}"
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
