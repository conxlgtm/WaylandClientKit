#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GENERATED_PATHS=(
    protocols
    Sources/CWaylandProtocols/include/generated
    Sources/CWaylandProtocols/generated
)

SNAPSHOT_DIR="$(mktemp -d)"
trap 'rm -rf "$SNAPSHOT_DIR"' EXIT

for path in "${GENERATED_PATHS[@]}"; do
    source_path="$ROOT/$path"
    snapshot_path="$SNAPSHOT_DIR/$path"

    [[ -e "$source_path" ]] || {
        echo "Missing generated verification path: $path"
        exit 1
    }

    mkdir -p "$(dirname "$snapshot_path")"
    cp -a "$source_path" "$snapshot_path"
done

"$ROOT/scripts/protocols/generate.sh"

diff_status=0
for path in "${GENERATED_PATHS[@]}"; do
    if ! diff -ru "$SNAPSHOT_DIR/$path" "$ROOT/$path"; then
        diff_status=1
    fi
done

if [[ "$diff_status" -ne 0 ]]; then
    echo "Generated protocol artifacts are not up to date."
    exit 1
fi

echo "Generated artifacts are up to date."
