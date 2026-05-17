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

"$ROOT/scripts/dev/swift.sh" package dump-symbol-graph \
    --minimum-access-level public \
    --skip-synthesized-members

SYMBOL_GRAPH="$(
    find "$ROOT/.build" \
        -path "*/symbolgraph/WaylandClient.symbols.json" \
        -type f \
        -print \
        -quit
)"

if [[ ! -f "$SYMBOL_GRAPH" ]]; then
    echo "Missing WaylandClient symbol graph under .build/*/symbolgraph"
    exit 1
fi

if ! grep --fixed-strings --quiet '"module":{"name":"WaylandClient"' "$SYMBOL_GRAPH"; then
    echo "WaylandClient symbol graph has unexpected module metadata"
    exit 1
fi

"$ROOT/scripts/ci/verify-docc-symbol-links.py"
