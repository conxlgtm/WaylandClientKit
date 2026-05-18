#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/swift-runtime-env.sh"

if [[ -z "${LINUX_SOURCEKIT_LIB_PATH:-}" ]]; then
    RUNTIME_RESOURCE_PATH="$(
        "${SCRIPT_DIR}/swift.sh" -print-target-info 2>/dev/null \
            | sed -n 's/.*"runtimeResourcePath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
            | head -n 1
    )"

    if [[ -n "${RUNTIME_RESOURCE_PATH}" ]]; then
        SOURCEKIT_PATH="$(dirname "${RUNTIME_RESOURCE_PATH}")/libsourcekitdInProc.so"
        if [[ -f "${SOURCEKIT_PATH}" ]]; then
            export LINUX_SOURCEKIT_LIB_PATH="${SOURCEKIT_PATH}"
            export LD_LIBRARY_PATH="$(dirname "${SOURCEKIT_PATH}"):${LD_LIBRARY_PATH:-}"
        fi
    fi
fi

if [[ -n "${SWIFTLINT_BIN:-}" ]]; then
    exec "${SWIFTLINT_BIN}" "$@"
fi

if command -v swiftlint >/dev/null 2>&1; then
    exec "$(command -v swiftlint)" "$@"
fi

echo "swiftlint not found on PATH." >&2
echo "Install SwiftLint 0.61+ or set SWIFTLINT_BIN=/path/to/swiftlint." >&2
exit 1
