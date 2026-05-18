#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/swift-runtime-env.sh"

if [[ -n "${SWIFT_FORMAT_BIN:-}" ]]; then
    exec "${SWIFT_FORMAT_BIN}" "$@"
fi

SWIFTLY_HOME_DIR="${SWIFTLY_HOME:-$HOME/.local/share/swiftly}"
SWIFTLY_TOOLCHAIN_FORMAT=""
if [[ -d "${SWIFTLY_HOME_DIR}/toolchains" ]]; then
    SWIFTLY_TOOLCHAIN_FORMAT="$(
        find "${SWIFTLY_HOME_DIR}/toolchains" -path '*/usr/bin/swift-format' -type f \
            | sort \
            | tail -n 1
    )"
fi

if [[ -n "${SWIFTLY_TOOLCHAIN_FORMAT}" ]]; then
    exec "${SWIFTLY_TOOLCHAIN_FORMAT}" "$@"
fi

if command -v swift-format >/dev/null 2>&1; then
    exec "$(command -v swift-format)" "$@"
fi

if swift format --version >/dev/null 2>&1; then
    exec swift format "$@"
fi

echo "swift-format not found on PATH." >&2
echo "Install a Swift toolchain that provides 'swift format' or 'swift-format'." >&2
exit 1
