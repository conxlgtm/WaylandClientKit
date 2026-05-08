#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$ROOT/scripts/protocols/sources.sh"

wayland_candidates=()
xdg_candidates=()
decoration_candidates=()
viewporter_candidates=()
fractional_scale_candidates=()

mapfile -t wayland_candidates < <(protocol_sources_wayland_core_candidates)
mapfile -t xdg_candidates < <(protocol_sources_xdg_shell_candidates)
mapfile -t decoration_candidates < <(protocol_sources_xdg_decoration_candidates)
mapfile -t viewporter_candidates < <(protocol_sources_viewporter_candidates)
mapfile -t fractional_scale_candidates < <(protocol_sources_fractional_scale_candidates)

WAYLAND_CORE_XML_SOURCE="$(protocol_sources_first_existing_file "${wayland_candidates[@]}" || true)"
XDG_SHELL_XML_SOURCE="$(protocol_sources_first_existing_file "${xdg_candidates[@]}" || true)"
XDG_DECORATION_XML_SOURCE="$(
    protocol_sources_first_existing_file "${decoration_candidates[@]}" || true
)"
VIEWPORTER_XML_SOURCE="$(protocol_sources_first_existing_file "${viewporter_candidates[@]}" || true)"
FRACTIONAL_SCALE_XML_SOURCE="$(
    protocol_sources_first_existing_file "${fractional_scale_candidates[@]}" || true
)"

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

[[ -f "$XDG_DECORATION_XML_SOURCE" ]] || {
    echo "Missing xdg-decoration XML. Checked:"
    printf '  %s\n' "${decoration_candidates[@]}"
    exit 1
}

[[ -f "$VIEWPORTER_XML_SOURCE" ]] || {
    echo "Missing viewporter XML. Checked:"
    printf '  %s\n' "${viewporter_candidates[@]}"
    exit 1
}

[[ -f "$FRACTIONAL_SCALE_XML_SOURCE" ]] || {
    echo "Missing fractional-scale XML. Checked:"
    printf '  %s\n' "${fractional_scale_candidates[@]}"
    exit 1
}

mkdir -p \
    "$ROOT/protocols/upstream/core" \
    "$ROOT/protocols/upstream/stable/xdg-shell" \
    "$ROOT/protocols/upstream/legacy-unstable/xdg-decoration" \
    "$ROOT/protocols/upstream/stable/viewporter" \
    "$ROOT/protocols/upstream/staging/fractional-scale"

cp "$WAYLAND_CORE_XML_SOURCE" "$ROOT/protocols/upstream/core/wayland.xml"
cp "$XDG_SHELL_XML_SOURCE" "$ROOT/protocols/upstream/stable/xdg-shell/xdg-shell.xml"
cp "$XDG_DECORATION_XML_SOURCE" \
    "$ROOT/protocols/upstream/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1.xml"
cp "$VIEWPORTER_XML_SOURCE" "$ROOT/protocols/upstream/stable/viewporter/viewporter.xml"
cp "$FRACTIONAL_SCALE_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/fractional-scale/fractional-scale-v1.xml"

echo "Vendored protocol XML into $ROOT/protocols"
