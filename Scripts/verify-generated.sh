#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/Scripts/generate-protocols.sh"

git -C "$ROOT" diff --quiet -- \
Protocols \
Sources/CWaylandProtocols || {
    echo "Generated artifacts are not up to date."
    git -C "$ROOT" --no-pager diff -- Protocols Sources/CWaylandProtocols
    exit 1
}

echo "Generated artifacts are up to date."