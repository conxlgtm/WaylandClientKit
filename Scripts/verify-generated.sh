#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/Scripts/generate-protocols.sh"

GENERATED_PATHS=(
    Protocols
    Sources/CWaylandProtocols/include/generated
    Sources/CWaylandProtocols/generated
)

git -C "$ROOT" diff --quiet -- \
    "${GENERATED_PATHS[@]}" || {
    echo "Generated protocol artifacts are not up to date."
    git -C "$ROOT" --no-pager diff -- "${GENERATED_PATHS[@]}"
    exit 1
}

echo "Generated artifacts are up to date."
