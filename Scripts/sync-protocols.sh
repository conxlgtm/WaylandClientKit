#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEFAULT_WAYLAND_CORE_XML="/usr/share/wayland/wayland.xml"
DEFAULT_XDG_SHELL_XML="/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml"

if [[ ! -f "$DEFAULT_XDG_SHELL_XML" ]]; then
    DEFAULT_XDG_SHELL_XML="/usr/share/qt6/wayland/protocols/xdg-shell/xdg-shell.xml"
fi

WAYLAND_CORE_XML_SOURCE="${WAYLAND_CORE_XML_SOURCE:-$DEFAULT_WAYLAND_CORE_XML}"
XDG_SHELL_XML_SOURCE="${XDG_SHELL_XML_SOURCE:-$DEFAULT_XDG_SHELL_XML}"

[[ -f "$WAYLAND_CORE_XML_SOURCE" ]] || {
    echo "Missing wayland core XML: $WAYLAND_CORE_XML_SOURCE"
    exit 1
}

[[ -f "$XDG_SHELL_XML_SOURCE" ]] || {
    echo "Missing xdg-shell XML: $XDG_SHELL_XML_SOURCE"
    exit 1
}

mkdir -p \
    "$ROOT/Protocols/core" \
    "$ROOT/Protocols/stable/xdg-shell"

cp "$WAYLAND_CORE_XML_SOURCE" "$ROOT/Protocols/core/wayland.xml"
cp "$XDG_SHELL_XML_SOURCE" "$ROOT/Protocols/stable/xdg-shell/xdg-shell.xml"

echo "Vendored protocol XML into $ROOT/Protocols"
