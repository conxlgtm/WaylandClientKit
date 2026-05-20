#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'USAGE'
usage: scripts/ci/repeat-test.sh --count N --filter TEST_FILTER [-- swift-test-arguments...]
USAGE
}

count=""
filter=""
extra_args=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --count)
            if [[ $# -lt 2 ]]; then
                usage
                exit 2
            fi
            count="$2"
            shift 2
            ;;
        --filter)
            if [[ $# -lt 2 ]]; then
                usage
                exit 2
            fi
            filter="$2"
            shift 2
            ;;
        --)
            shift
            extra_args=("$@")
            break
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

if [[ -z "$count" || -z "$filter" || ! "$count" =~ ^[1-9][0-9]*$ ]]; then
    usage
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

for run in $(seq 1 "$count"); do
    echo "repeat-test: run ${run}/${count}: ${filter}"
    env CC="${REPO_ROOT}/scripts/dev/clang-filter-index-store.sh" \
        "${REPO_ROOT}/scripts/dev/swift.sh" test \
            --filter "${filter}" \
            "${extra_args[@]}"
done
