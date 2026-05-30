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
xdg_activation_candidates=()
xdg_toplevel_icon_candidates=()
xdg_system_bell_candidates=()
primary_selection_candidates=()
idle_inhibit_candidates=()
linux_dmabuf_candidates=()
relative_pointer_candidates=()
pointer_constraints_candidates=()
linux_drm_syncobj_candidates=()
fifo_candidates=()
commit_timing_candidates=()
content_type_candidates=()
alpha_modifier_candidates=()
tearing_control_candidates=()
color_representation_candidates=()
color_management_candidates=()

mapfile -t wayland_candidates < <(protocol_sources_wayland_core_candidates)
mapfile -t xdg_candidates < <(protocol_sources_xdg_shell_candidates)
mapfile -t decoration_candidates < <(protocol_sources_xdg_decoration_candidates)
mapfile -t xdg_output_candidates < <(protocol_sources_xdg_output_candidates)
mapfile -t viewporter_candidates < <(protocol_sources_viewporter_candidates)
mapfile -t presentation_time_candidates < <(protocol_sources_presentation_time_candidates)
mapfile -t fractional_scale_candidates < <(protocol_sources_fractional_scale_candidates)
mapfile -t xdg_activation_candidates < <(protocol_sources_xdg_activation_candidates)
mapfile -t xdg_toplevel_icon_candidates < <(protocol_sources_xdg_toplevel_icon_candidates)
mapfile -t xdg_system_bell_candidates < <(protocol_sources_xdg_system_bell_candidates)
mapfile -t primary_selection_candidates < <(protocol_sources_primary_selection_candidates)
mapfile -t idle_inhibit_candidates < <(protocol_sources_idle_inhibit_candidates)
mapfile -t linux_dmabuf_candidates < <(protocol_sources_linux_dmabuf_candidates)
mapfile -t relative_pointer_candidates < <(protocol_sources_relative_pointer_candidates)
mapfile -t pointer_constraints_candidates < <(protocol_sources_pointer_constraints_candidates)
mapfile -t linux_drm_syncobj_candidates < <(protocol_sources_linux_drm_syncobj_candidates)
mapfile -t fifo_candidates < <(protocol_sources_fifo_candidates)
mapfile -t commit_timing_candidates < <(protocol_sources_commit_timing_candidates)
mapfile -t content_type_candidates < <(protocol_sources_content_type_candidates)
mapfile -t alpha_modifier_candidates < <(protocol_sources_alpha_modifier_candidates)
mapfile -t tearing_control_candidates < <(protocol_sources_tearing_control_candidates)
mapfile -t color_representation_candidates < <(protocol_sources_color_representation_candidates)
mapfile -t color_management_candidates < <(protocol_sources_color_management_candidates)

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
XDG_ACTIVATION_XML_SOURCE="$(
    protocol_sources_first_existing_file "${xdg_activation_candidates[@]}" || true
)"
XDG_TOPLEVEL_ICON_XML_SOURCE="$(
    protocol_sources_first_existing_file "${xdg_toplevel_icon_candidates[@]}" || true
)"
XDG_SYSTEM_BELL_XML_SOURCE="$(
    protocol_sources_first_existing_file "${xdg_system_bell_candidates[@]}" || true
)"
PRIMARY_SELECTION_XML_SOURCE="$(
    protocol_sources_first_existing_file "${primary_selection_candidates[@]}" || true
)"
IDLE_INHIBIT_XML_SOURCE="$(
    protocol_sources_first_existing_file "${idle_inhibit_candidates[@]}" || true
)"
LINUX_DMABUF_XML_SOURCE="$(
    protocol_sources_first_existing_file "${linux_dmabuf_candidates[@]}" || true
)"
RELATIVE_POINTER_XML_SOURCE="$(
    protocol_sources_first_existing_file "${relative_pointer_candidates[@]}" || true
)"
POINTER_CONSTRAINTS_XML_SOURCE="$(
    protocol_sources_first_existing_file "${pointer_constraints_candidates[@]}" || true
)"
LINUX_DRM_SYNCOBJ_XML_SOURCE="$(
    protocol_sources_first_existing_file "${linux_drm_syncobj_candidates[@]}" || true
)"
FIFO_XML_SOURCE="$(protocol_sources_first_existing_file "${fifo_candidates[@]}" || true)"
COMMIT_TIMING_XML_SOURCE="$(
    protocol_sources_first_existing_file "${commit_timing_candidates[@]}" || true
)"
CONTENT_TYPE_XML_SOURCE="$(
    protocol_sources_first_existing_file "${content_type_candidates[@]}" || true
)"
ALPHA_MODIFIER_XML_SOURCE="$(
    protocol_sources_first_existing_file "${alpha_modifier_candidates[@]}" || true
)"
TEARING_CONTROL_XML_SOURCE="$(
    protocol_sources_first_existing_file "${tearing_control_candidates[@]}" || true
)"
COLOR_REPRESENTATION_XML_SOURCE="$(
    protocol_sources_first_existing_file "${color_representation_candidates[@]}" || true
)"
COLOR_MANAGEMENT_XML_SOURCE="$(
    protocol_sources_first_existing_file "${color_management_candidates[@]}" || true
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

[[ -f "$XDG_ACTIVATION_XML_SOURCE" ]] || {
    echo "Missing xdg-activation XML. Checked:"
    printf '  %s\n' "${xdg_activation_candidates[@]}"
    exit 1
}

[[ -f "$XDG_TOPLEVEL_ICON_XML_SOURCE" ]] || {
    echo "Missing xdg-toplevel-icon XML. Checked:"
    printf '  %s\n' "${xdg_toplevel_icon_candidates[@]}"
    exit 1
}

[[ -f "$XDG_SYSTEM_BELL_XML_SOURCE" ]] || {
    echo "Missing xdg-system-bell XML. Checked:"
    printf '  %s\n' "${xdg_system_bell_candidates[@]}"
    exit 1
}

[[ -f "$PRIMARY_SELECTION_XML_SOURCE" ]] || {
    echo "Missing primary-selection XML. Checked:"
    printf '  %s\n' "${primary_selection_candidates[@]}"
    exit 1
}

[[ -f "$IDLE_INHIBIT_XML_SOURCE" ]] || {
    echo "Missing idle-inhibit XML. Checked:"
    printf '  %s\n' "${idle_inhibit_candidates[@]}"
    exit 1
}

[[ -f "$LINUX_DMABUF_XML_SOURCE" ]] || {
    echo "Missing linux-dmabuf XML. Checked:"
    printf '  %s\n' "${linux_dmabuf_candidates[@]}"
    exit 1
}

[[ -f "$RELATIVE_POINTER_XML_SOURCE" ]] || {
    echo "Missing relative-pointer XML. Checked:"
    printf '  %s\n' "${relative_pointer_candidates[@]}"
    exit 1
}

[[ -f "$POINTER_CONSTRAINTS_XML_SOURCE" ]] || {
    echo "Missing pointer-constraints XML. Checked:"
    printf '  %s\n' "${pointer_constraints_candidates[@]}"
    exit 1
}

[[ -f "$LINUX_DRM_SYNCOBJ_XML_SOURCE" ]] || {
    echo "Missing linux-drm-syncobj XML. Checked:"
    printf '  %s\n' "${linux_drm_syncobj_candidates[@]}"
    exit 1
}

[[ -f "$FIFO_XML_SOURCE" ]] || {
    echo "Missing FIFO XML. Checked:"
    printf '  %s\n' "${fifo_candidates[@]}"
    exit 1
}

[[ -f "$COMMIT_TIMING_XML_SOURCE" ]] || {
    echo "Missing commit-timing XML. Checked:"
    printf '  %s\n' "${commit_timing_candidates[@]}"
    exit 1
}

[[ -f "$CONTENT_TYPE_XML_SOURCE" ]] || {
    echo "Missing content-type XML. Checked:"
    printf '  %s\n' "${content_type_candidates[@]}"
    exit 1
}

[[ -f "$ALPHA_MODIFIER_XML_SOURCE" ]] || {
    echo "Missing alpha-modifier XML. Checked:"
    printf '  %s\n' "${alpha_modifier_candidates[@]}"
    exit 1
}

[[ -f "$TEARING_CONTROL_XML_SOURCE" ]] || {
    echo "Missing tearing-control XML. Checked:"
    printf '  %s\n' "${tearing_control_candidates[@]}"
    exit 1
}

[[ -f "$COLOR_REPRESENTATION_XML_SOURCE" ]] || {
    echo "Missing color-representation XML. Checked:"
    printf '  %s\n' "${color_representation_candidates[@]}"
    exit 1
}

[[ -f "$COLOR_MANAGEMENT_XML_SOURCE" ]] || {
    echo "Missing color-management XML. Checked:"
    printf '  %s\n' "${color_management_candidates[@]}"
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
    "$ROOT/protocols/upstream/staging/xdg-activation" \
    "$ROOT/protocols/upstream/staging/xdg-toplevel-icon" \
    "$ROOT/protocols/upstream/staging/xdg-system-bell" \
    "$ROOT/protocols/upstream/staging/linux-drm-syncobj" \
    "$ROOT/protocols/upstream/staging/fifo" \
    "$ROOT/protocols/upstream/staging/commit-timing" \
    "$ROOT/protocols/upstream/staging/content-type" \
    "$ROOT/protocols/upstream/staging/alpha-modifier" \
    "$ROOT/protocols/upstream/staging/tearing-control" \
    "$ROOT/protocols/upstream/staging/color-representation" \
    "$ROOT/protocols/upstream/staging/color-management" \
    "$ROOT/protocols/upstream/legacy-unstable/primary-selection" \
    "$ROOT/protocols/upstream/legacy-unstable/idle-inhibit" \
    "$ROOT/protocols/upstream/legacy-unstable/linux-dmabuf" \
    "$ROOT/protocols/upstream/legacy-unstable/relative-pointer" \
    "$ROOT/protocols/upstream/legacy-unstable/pointer-constraints"

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
cp "$XDG_ACTIVATION_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/xdg-activation/xdg-activation-v1.xml"
cp "$XDG_TOPLEVEL_ICON_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/xdg-toplevel-icon/xdg-toplevel-icon-v1.xml"
cp "$XDG_SYSTEM_BELL_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/xdg-system-bell/xdg-system-bell-v1.xml"
cp "$PRIMARY_SELECTION_XML_SOURCE" \
    "$ROOT/protocols/upstream/legacy-unstable/primary-selection/primary-selection-unstable-v1.xml"
cp "$IDLE_INHIBIT_XML_SOURCE" \
    "$ROOT/protocols/upstream/legacy-unstable/idle-inhibit/idle-inhibit-unstable-v1.xml"
cp "$LINUX_DMABUF_XML_SOURCE" \
    "$ROOT/protocols/upstream/legacy-unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml"
cp "$RELATIVE_POINTER_XML_SOURCE" \
    "$ROOT/protocols/upstream/legacy-unstable/relative-pointer/relative-pointer-unstable-v1.xml"
cp "$POINTER_CONSTRAINTS_XML_SOURCE" \
    "$ROOT/protocols/upstream/legacy-unstable/pointer-constraints/pointer-constraints-unstable-v1.xml"
cp "$LINUX_DRM_SYNCOBJ_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml"
cp "$FIFO_XML_SOURCE" "$ROOT/protocols/upstream/staging/fifo/fifo-v1.xml"
cp "$COMMIT_TIMING_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/commit-timing/commit-timing-v1.xml"
cp "$CONTENT_TYPE_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/content-type/content-type-v1.xml"
cp "$ALPHA_MODIFIER_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/alpha-modifier/alpha-modifier-v1.xml"
cp "$TEARING_CONTROL_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/tearing-control/tearing-control-v1.xml"
cp "$COLOR_REPRESENTATION_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/color-representation/color-representation-v1.xml"
cp "$COLOR_MANAGEMENT_XML_SOURCE" \
    "$ROOT/protocols/upstream/staging/color-management/color-management-v1.xml"

echo "Vendored protocol XML into $ROOT/protocols"
