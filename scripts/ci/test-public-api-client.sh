#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/swiftwayland-public-api-client.XXXXXX")"

cleanup() {
    rm -rf "${BUILD_DIR}"
}

trap cleanup EXIT

env CC="${REPO_ROOT}/scripts/dev/clang-filter-index-store.sh" \
    "${REPO_ROOT}/scripts/dev/swift.sh" test \
        --package-path "${REPO_ROOT}/IntegrationTests/PublicAPIClient" \
        --scratch-path "${BUILD_DIR}" \
        --filter WaylandDisplayPublicIntegrationTests
