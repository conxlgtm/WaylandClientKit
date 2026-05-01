#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$ROOT/Scripts/protocol-sources.sh"

wayland_candidates=()
xdg_candidates=()

mapfile -t wayland_candidates < <(protocol_sources_wayland_core_candidates)
mapfile -t xdg_candidates < <(protocol_sources_xdg_shell_candidates)

WAYLAND_CORE_XML_SOURCE="$(protocol_sources_first_existing_file "${wayland_candidates[@]}" || true)"
XDG_SHELL_XML_SOURCE="$(protocol_sources_first_existing_file "${xdg_candidates[@]}" || true)"

[[ -f "$WAYLAND_CORE_XML_SOURCE" ]] || {
    echo "Missing wayland core XML. Checked:"
    printf '  %s\n' "${wayland_candidates[@]}"
    exit 1
}

[[ -f "$XDG_SHELL_XML_SOURCE" ]] || {
    echo "Missing xdg-shell XML. Checked:"
    printf '  %s\n' "${xdg_candidates[@]}"
    exit 1
}

mkdir -p \
    "$ROOT/Protocols/core" \
    "$ROOT/Protocols/stable/xdg-shell"

cp "$WAYLAND_CORE_XML_SOURCE" "$ROOT/Protocols/core/wayland.xml"
cp "$XDG_SHELL_XML_SOURCE" "$ROOT/Protocols/stable/xdg-shell/xdg-shell.xml"

echo "Vendored protocol XML into $ROOT/Protocols"
