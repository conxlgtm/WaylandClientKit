#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$ROOT/scripts/protocols/sources.sh"

wayland_candidates=()
xdg_candidates=()
decoration_candidates=()
xdg_output_candidates=()
viewporter_candidates=()
presentation_time_candidates=()
fractional_scale_candidates=()
primary_selection_candidates=()
linux_dmabuf_candidates=()

mapfile -t wayland_candidates < <(protocol_sources_wayland_core_candidates)
mapfile -t xdg_candidates < <(protocol_sources_xdg_shell_candidates)
mapfile -t decoration_candidates < <(protocol_sources_xdg_decoration_candidates)
mapfile -t xdg_output_candidates < <(protocol_sources_xdg_output_candidates)
mapfile -t viewporter_candidates < <(protocol_sources_viewporter_candidates)
mapfile -t presentation_time_candidates < <(protocol_sources_presentation_time_candidates)
mapfile -t fractional_scale_candidates < <(protocol_sources_fractional_scale_candidates)
mapfile -t primary_selection_candidates < <(protocol_sources_primary_selection_candidates)
mapfile -t linux_dmabuf_candidates < <(protocol_sources_linux_dmabuf_candidates)

WAYLAND_CORE_XML_SOURCE="$(protocol_sources_first_existing_file "${wayland_candidates[@]}" || true)"
XDG_SHELL_XML_SOURCE="$(protocol_sources_first_existing_file "${xdg_candidates[@]}" || true)"
XDG_DECORATION_XML_SOURCE="$(
    protocol_sources_first_existing_file "${decoration_candidates[@]}" || true
)"
XDG_OUTPUT_XML_SOURCE="$(protocol_sources_first_existing_file "${xdg_output_candidates[@]}" || true)"
VIEWPORTER_XML_SOURCE="$(protocol_sources_first_existing_file "${viewporter_candidates[@]}" || true)"
PRESENTATION_TIME_XML_SOURCE="$(
    protocol_sources_first_existing_file "${presentation_time_candidates[@]}" || true
)"
FRACTIONAL_SCALE_XML_SOURCE="$(
    protocol_sources_first_existing_file "${fractional_scale_candidates[@]}" || true
)"
PRIMARY_SELECTION_XML_SOURCE="$(
    protocol_sources_first_existing_file "${primary_selection_candidates[@]}" || true
)"
LINUX_DMABUF_XML_SOURCE="$(
    protocol_sources_first_existing_file "${linux_dmabuf_candidates[@]}" || true
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

[[ -f "$XDG_OUTPUT_XML_SOURCE" ]] || {
    echo "Missing xdg-output XML. Checked:"
    printf '  %s\n' "${xdg_output_candidates[@]}"
    exit 1
}

[[ -f "$VIEWPORTER_XML_SOURCE" ]] || {
    echo "Missing viewporter XML. Checked:"
    printf '  %s\n' "${viewporter_candidates[@]}"
    exit 1
}

[[ -f "$PRESENTATION_TIME_XML_SOURCE" ]] || {
    echo "Missing presentation-time XML. Checked:"
    printf '  %s\n' "${presentation_time_candidates[@]}"
    exit 1
}

[[ -f "$FRACTIONAL_SCALE_XML_SOURCE" ]] || {
    echo "Missing fractional-scale XML. Checked:"
    printf '  %s\n' "${fractional_scale_candidates[@]}"
    exit 1
}

[[ -f "$PRIMARY_SELECTION_XML_SOURCE" ]] || {
    echo "Missing primary-selection XML. Checked:"
    printf '  %s\n' "${primary_selection_candidates[@]}"
    exit 1
}

[[ -f "$LINUX_DMABUF_XML_SOURCE" ]] || {
    echo "Missing linux-dmabuf XML. Checked:"
    printf '  %s\n' "${linux_dmabuf_candidates[@]}"
    exit 1
}

mkdir -p \
    "$ROOT/protocols/upstream/core" \
    "$ROOT/protocols/upstream/stable/xdg-shell" \
    "$ROOT/protocols/upstream/legacy-unstable/xdg-decoration" \
    "$ROOT/protocols/upstream/legacy-unstable/xdg-output" \
    "$ROOT/protocols/upstream/stable/viewporter" \
    "$ROOT/protocols/upstream/stable/presentation-time" \
    "$ROOT/protocols/upstream/staging/fractional-scale" \
    "$ROOT/protocols/upstream/legacy-unstable/primary-selection" \
    "$ROOT/protocols/upstream/legacy-unstable/linux-dmabuf"

cp "$WAYLAND_CORE_XML_SOURCE" "$ROOT/protocols/upstream/core/wayland.xml"
cp "$XDG_SHELL_XML_SOURCE" "$ROOT/protocols/upstream/stable/xdg-shell/xdg-shell.xml"
cp "$XDG_DECORATION_XML_SOURCE" \
    "$ROOT/protocols/upstream/legacy-unstable/xdg-decoration/xdg-decoration-unstable-v1.xml"
cp "$XDG_OUTPUT_XML_SOURCE" \
    "$ROOT/protocols/upstream/legacy-unstable/xdg-output/xdg-output-unstable-v1.xml"
cp "$VIEWPORTER_XML_SOURCE" "$ROOT/protocols/upstream/stable/viewporter/viewporter.xml"
cp "$PRESENTATION_TIME_XML_SOURCE" \
    "$ROOT/protocols/upstream/stable/presentation-time/presentation-time.xml"
cp "$FRACTIONAL_SCALE_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/fractional-scale/fractional-scale-v1.xml"
cp "$PRIMARY_SELECTION_XML_SOURCE" \
    "$ROOT/protocols/upstream/legacy-unstable/primary-selection/primary-selection-unstable-v1.xml"
cp "$LINUX_DMABUF_XML_SOURCE" \
    "$ROOT/protocols/upstream/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml"

echo "Vendored protocol XML into $ROOT/protocols"
