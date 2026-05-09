#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

env CC="${REPO_ROOT}/scripts/dev/clang-filter-index-store.sh" \
    "${REPO_ROOT}/scripts/dev/swift.sh" test \
        -Xswiftc -warnings-as-errors
