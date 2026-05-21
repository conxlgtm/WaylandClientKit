#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'USAGE'
usage: scripts/ci/headless-request-tests.sh [plain|tsan|asan]
USAGE
}

mode="${1:-plain}"
if [[ $# -gt 1 ]]; then
    usage
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROCESS_TIMEOUT_SECONDS="${SWIFT_WAYLAND_REQUEST_PROCESS_TIMEOUT_SECONDS:-${SWIFT_WAYLAND_INTEGRATION_PROCESS_TIMEOUT_SECONDS:-600}}"
TSAN_SUPPRESSIONS="${REPO_ROOT}/scripts/safety/tsan-suppressions.txt"

case "$mode" in
    plain)
        swift_args=(test)
        ;;
    tsan)
        export TSAN_OPTIONS="${TSAN_OPTIONS:+${TSAN_OPTIONS}:}detect_deadlocks=0:suppressions=${TSAN_SUPPRESSIONS}"
        swift_args=(test --sanitize=thread --parallel --num-workers 1)
        ;;
    asan)
        export ASAN_OPTIONS="${ASAN_OPTIONS:-detect_leaks=0}"
        swift_args=(test --sanitize=address)
        ;;
    *)
        usage
        exit 2
        ;;
esac

export SWIFT_WAYLAND_ENABLE_WINDOW_CONTROL_REQUEST_TESTS=1
export SWIFT_WAYLAND_ENABLE_DND_SOURCE_REQUEST_TESTS=1

run_request_suite() {
    local filter="$1"

    "${REPO_ROOT}/scripts/smoke/with-headless-weston.sh" -- \
        env CC="${REPO_ROOT}/scripts/dev/clang-filter-index-store.sh" \
        timeout "${PROCESS_TIMEOUT_SECONDS}s" \
        "${REPO_ROOT}/scripts/dev/swift.sh" "${swift_args[@]}" --filter "$filter"
}

run_request_suite "WindowControlPublicRequestTests"
run_request_suite "WindowDragSourcePublicRequestTests"
