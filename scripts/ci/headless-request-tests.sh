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

case "$mode" in
    plain)
        swift_args=(test --filter 'WindowControlPublicRequestTests|WindowDragSourcePublicRequestTests')
        ;;
    tsan)
        swift_args=(test --sanitize=thread --filter 'WindowControlPublicRequestTests|WindowDragSourcePublicRequestTests')
        ;;
    asan)
        export ASAN_OPTIONS="${ASAN_OPTIONS:-detect_leaks=0}"
        swift_args=(test --sanitize=address --filter 'WindowControlPublicRequestTests|WindowDragSourcePublicRequestTests')
        ;;
    *)
        usage
        exit 2
        ;;
esac

export SWIFT_WAYLAND_ENABLE_WINDOW_CONTROL_REQUEST_TESTS=1
export SWIFT_WAYLAND_ENABLE_DND_SOURCE_REQUEST_TESTS=1

"${REPO_ROOT}/scripts/smoke/with-headless-weston.sh" -- \
    env CC="${REPO_ROOT}/scripts/dev/clang-filter-index-store.sh" \
    "${REPO_ROOT}/scripts/dev/swift.sh" "${swift_args[@]}"
