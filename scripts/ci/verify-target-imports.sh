#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

failed=0

check_forbidden_imports_in_path() {
    local label="$1"
    local path="$2"
    shift
    shift

    if [[ ! -d "$path" ]]; then
        echo "Missing source path for $label: $path"
        failed=1
        return 0
    fi

    for module in "$@"; do
        if rg --line-number "^import ${module}\b" "$path"; then
            echo "$label must not import $module"
            failed=1
        fi
    done
}

check_forbidden_imports() {
    local target="$1"
    shift

    check_forbidden_imports_in_path "$target" "$ROOT/Sources/$target" "$@"
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
check_forbidden_imports_in_path \
    WaylandGraphicsCore \
    "$ROOT/Sources/WaylandGraphicsPreview" \
    WaylandClient

if [[ "$failed" -ne 0 ]]; then
    exit 1
fi

echo "Target import boundaries are valid."
