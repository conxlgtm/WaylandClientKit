#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CATALOG="$ROOT/Sources/WaylandClient/WaylandClient.docc"
ARTICLE="$CATALOG/WaylandClient.md"

missing=0

if [[ ! -d "$CATALOG" ]]; then
    echo "Missing DocC catalog: Sources/WaylandClient/WaylandClient.docc"
    missing=1
fi

if [[ ! -f "$ARTICLE" ]]; then
    echo "Missing DocC article: Sources/WaylandClient/WaylandClient.docc/WaylandClient.md"
    missing=1
fi

if [[ "$missing" -ne 0 ]]; then
    exit "$missing"
fi

dump_log="$(mktemp)"
trap 'rm -f "$dump_log"' EXIT

if [[ -d "$ROOT/.build" ]]; then
    find "$ROOT/.build" \
        -path "*/symbolgraph/WaylandClient.symbols.json" \
        -type f \
        -delete
fi

set +e
env CC="$ROOT/scripts/dev/clang-filter-index-store.sh" \
    "$ROOT/scripts/dev/swift.sh" package dump-symbol-graph \
        --minimum-access-level public \
        --skip-synthesized-members \
        >"$dump_log" 2>&1
dump_status="$?"
set -e

SYMBOL_GRAPH="$(
    find "$ROOT/.build" \
        -path "*/symbolgraph/WaylandClient.symbols.json" \
        -type f \
        -print \
        -quit
)"

if [[ ! -f "$SYMBOL_GRAPH" ]]; then
    cat "$dump_log" >&2
    echo "Missing WaylandClient symbol graph under .build/*/symbolgraph"
    exit 1
fi

if ! grep --fixed-strings --quiet '"module":{"name":"WaylandClient"' "$SYMBOL_GRAPH"; then
    cat "$dump_log" >&2
    echo "WaylandClient symbol graph has unexpected module metadata"
    exit 1
fi

if [[ "$dump_status" -ne 0 ]]; then
    if grep -Eq "Failed to emit symbol graph for 'SwiftWaylandPackage(Discovered)?Tests'" "$dump_log"; then
        echo "SwiftPM skipped package test harness symbol graphs after emitting WaylandClient."
    else
        cat "$dump_log" >&2
        exit "$dump_status"
    fi
fi

"$ROOT/scripts/ci/verify-docc-symbol-links.py"
