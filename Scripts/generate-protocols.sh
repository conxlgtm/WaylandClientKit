#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROTO_DIR="$ROOT/Protocols"
OUT_DIR="$ROOT/Sources/CWaylandProtocols"
GEN_INC="$OUT_DIR/include/generated"
GEN_SRC="$OUT_DIR/generated"

command -v wayland-scanner >/dev/null 2>&1 || {
    echo "wayland-scanner not found on PATH"
    exit 1
}

[[ -f "$PROTO_DIR/core/wayland.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/core/wayland.xml"
    exit 1
}

[[ -f "$PROTO_DIR/stable/xdg-shell/xdg-shell.xml" ]] || {
    echo "Missing vendored protocol: $PROTO_DIR/stable/xdg-shell/xdg-shell.xml"
    exit 1
}

rm -rf "$GEN_INC" "$GEN_SRC"
mkdir -p "$GEN_INC" "$GEN_SRC" "$OUT_DIR/shims"

wayland-scanner client-header \
    "$PROTO_DIR/core/wayland.xml" \
    "$GEN_INC/wayland-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/core/wayland.xml" \
    "$GEN_SRC/wayland-protocol.c"

wayland-scanner client-header \
    "$PROTO_DIR/stable/xdg-shell/xdg-shell.xml" \
    "$GEN_INC/xdg-shell-client-protocol.h"

wayland-scanner private-code \
    "$PROTO_DIR/stable/xdg-shell/xdg-shell.xml" \
    "$GEN_SRC/xdg-shell-protocol.c"

echo "Generated Wayland protocol artifacts in $OUT_DIR"
