#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

failed=0

check_forbidden_imports() {
    local target="$1"
    shift
    local path="$ROOT/Sources/$target"

    [[ -d "$path" ]] || return 0

    for module in "$@"; do
        if rg --line-number "^import ${module}\b" "$path"; then
            echo "$target must not import $module"
            failed=1
        fi
    done
}

check_forbidden_imports \
    WaylandRaw \
    WaylandClient \
    WaylandKeyboard \
    WaylandCursor \
    WaylandGraphicsCore \
    WaylandGraphicsPreview

check_forbidden_imports WaylandKeyboard WaylandClient
check_forbidden_imports WaylandCursor WaylandClient
check_forbidden_imports WaylandGraphicsCore WaylandClient

if [[ "$failed" -ne 0 ]]; then
    exit 1
fi

echo "Target import boundaries are valid."
