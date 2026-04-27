#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${SWIFT_BIN:-}" ]]; then
    exec "${SWIFT_BIN}" "$@"
fi

SWIFTLY_HOME_DIR="${SWIFTLY_HOME:-$HOME/.local/share/swiftly}"
SWIFTLY_TOOLCHAIN_SWIFT=""
if [[ -d "${SWIFTLY_HOME_DIR}/toolchains" ]]; then
    SWIFTLY_TOOLCHAIN_SWIFT="$(
        find "${SWIFTLY_HOME_DIR}/toolchains" -path '*/usr/bin/swift' \
            | sort \
            | tail -n 1
    )"
fi

if [[ -n "${SWIFTLY_TOOLCHAIN_SWIFT}" ]]; then
    exec "${SWIFTLY_TOOLCHAIN_SWIFT}" "$@"
fi

exec swift "$@"
