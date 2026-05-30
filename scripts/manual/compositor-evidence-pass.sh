#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

duration_seconds=5
auto_close=0
print_summary=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --duration-seconds)
            duration_seconds="${2:?missing value for --duration-seconds}"
            shift 2
            ;;
        --auto-close)
            auto_close=1
            shift
            ;;
        --print-summary)
            print_summary=1
            shift
            ;;
        *)
            echo "unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

example_args=(--duration-seconds "$duration_seconds")
if [[ "$auto_close" -eq 1 ]]; then
    example_args+=(--auto-close)
fi
if [[ "$print_summary" -eq 1 ]]; then
    example_args+=(--print-summary)
fi

run_line() {
    local target="$1"
    shift
    printf './scripts/dev/swift.sh run %s' "$target"
    if [[ "$#" -gt 0 ]]; then
        printf ' %q' "$@"
    fi
    printf '\n'
}

section() {
    printf '\n%s\n' "$1"
}

echo "SwiftWayland compositor evidence pass"
echo "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-<unset>}"
echo "Use these commands under each compositor, then record results in docs/compositor-matrix.md."
echo
echo "Build gate:"
echo "./scripts/ci/test-examples-build.sh"
echo
echo "Protocol facts:"
echo "./scripts/smoke/collect-compositor-facts.sh --include-smoke"

section "Surface"
run_line SurfaceRegionSmoke "${example_args[@]}"
run_line DamageRegionSmoke "${example_args[@]}"
run_line SubsurfaceSmoke "${example_args[@]}"

section "Cursor"
run_line CursorPolicySmoke
run_line CustomCursorSmoke

section "Desktop integration"
run_line XDGActivationSmoke
run_line WindowIconSmoke "${example_args[@]}"
run_line IdleInhibitSmoke "${example_args[@]}"
run_line SystemBellSmoke "${example_args[@]}"

section "Input"
run_line PointerCaptureSmoke
run_line TextInputSmoke --auto-close --print-summary
run_line SerialActionsProbe

section "Data"
run_line DataTransferSmoke --auto-close --print-summary

section "Presentation and graphics"
run_line PresentationFeedbackAnimation "${example_args[@]}"
run_line GPUPreviewSmokeClient
