#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

output_file="$(mktemp "${TMPDIR:-/tmp}/swiftwayland-swiftbuild.XXXXXX")"

cleanup() {
    rm -f "${output_file}"
}
trap cleanup EXIT

set +e
env CC="${REPO_ROOT}/scripts/dev/clang-filter-index-store.sh" \
    "${REPO_ROOT}/scripts/dev/swift.sh" build \
        --disable-index-store \
        --build-system swiftbuild \
        >"${output_file}" 2>&1
status="$?"
set -e

if [[ "$status" -eq 0 ]]; then
    echo "swiftbuild-smoke: supported"
    cat "${output_file}"
    exit 0
fi

if grep -Eiq 'unknown option|unsupported|not supported' "${output_file}"; then
    echo "swiftbuild-smoke: unsupported"
    cat "${output_file}"
    exit 0
fi

if grep -Fq 'Unexpected toolchain layout' "${output_file}"; then
    echo "swiftbuild-smoke: failed-toolchain-layout"
    cat "${output_file}"
    exit 0
fi

echo "swiftbuild-smoke: failed-package"
cat "${output_file}"
exit "$status"
