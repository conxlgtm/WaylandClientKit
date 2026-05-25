#!/usr/bin/env bash

# Shared protocol XML source resolution for bootstrap preflight and sync.

protocol_sources_pkg_config_variable() {
    local pkg_config="${PKG_CONFIG:-pkg-config}"
    local value

    command -v "$pkg_config" >/dev/null 2>&1 || return 0
    value="$("$pkg_config" --variable="$2" "$1" 2>/dev/null || true)"
    printf '%s\n' "${value/#\/\//\/}"
}

protocol_sources_wayland_core_candidates() {
    local wayland_client_dir wayland_scanner_dir

    if [[ -n "${WAYLAND_CORE_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$WAYLAND_CORE_XML_SOURCE"
        return 0
    fi

    wayland_client_dir="$(protocol_sources_pkg_config_variable wayland-client pkgdatadir)"
    wayland_scanner_dir="$(protocol_sources_pkg_config_variable wayland-scanner pkgdatadir)"

    printf '%s\n' \
        "${wayland_client_dir:+$wayland_client_dir/wayland.xml}" \
        "${wayland_scanner_dir:+$wayland_scanner_dir/wayland.xml}" \
        /usr/share/wayland/wayland.xml \
        /usr/local/share/wayland/wayland.xml
}

protocol_sources_xdg_shell_candidates() {
    local protocols_dir

    if [[ -n "${XDG_SHELL_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$XDG_SHELL_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/stable/xdg-shell/xdg-shell.xml}" \
        /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml \
        /usr/local/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml \
        /usr/share/qt6/wayland/protocols/xdg-shell/xdg-shell.xml
}

protocol_sources_xdg_decoration_candidates() {
    local protocols_dir

    if [[ -n "${XDG_DECORATION_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$XDG_DECORATION_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml}" \
        /usr/share/wayland-protocols/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml \
        /usr/local/share/wayland-protocols/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml
}

protocol_sources_xdg_output_candidates() {
    local protocols_dir

    if [[ -n "${XDG_OUTPUT_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$XDG_OUTPUT_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/unstable/xdg-output/xdg-output-unstable-v1.xml}" \
        /usr/share/wayland-protocols/unstable/xdg-output/xdg-output-unstable-v1.xml \
        /usr/local/share/wayland-protocols/unstable/xdg-output/xdg-output-unstable-v1.xml
}

protocol_sources_viewporter_candidates() {
    local protocols_dir

    if [[ -n "${VIEWPORTER_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$VIEWPORTER_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/stable/viewporter/viewporter.xml}" \
        /usr/share/wayland-protocols/stable/viewporter/viewporter.xml \
        /usr/local/share/wayland-protocols/stable/viewporter/viewporter.xml
}

protocol_sources_presentation_time_candidates() {
    local protocols_dir

    if [[ -n "${PRESENTATION_TIME_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$PRESENTATION_TIME_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/stable/presentation-time/presentation-time.xml}" \
        /usr/share/wayland-protocols/stable/presentation-time/presentation-time.xml \
        /usr/local/share/wayland-protocols/stable/presentation-time/presentation-time.xml
}

protocol_sources_fractional_scale_candidates() {
    local protocols_dir

    if [[ -n "${FRACTIONAL_SCALE_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$FRACTIONAL_SCALE_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/staging/fractional-scale/fractional-scale-v1.xml}" \
        /usr/share/wayland-protocols/staging/fractional-scale/fractional-scale-v1.xml \
        /usr/local/share/wayland-protocols/staging/fractional-scale/fractional-scale-v1.xml
}

protocol_sources_xdg_activation_candidates() {
    local protocols_dir

    if [[ -n "${XDG_ACTIVATION_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$XDG_ACTIVATION_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/staging/xdg-activation/xdg-activation-v1.xml}" \
        /usr/share/wayland-protocols/staging/xdg-activation/xdg-activation-v1.xml \
        /usr/local/share/wayland-protocols/staging/xdg-activation/xdg-activation-v1.xml
}

protocol_sources_primary_selection_candidates() {
    local protocols_dir

    if [[ -n "${PRIMARY_SELECTION_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$PRIMARY_SELECTION_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/unstable/primary-selection/primary-selection-unstable-v1.xml}" \
        /usr/share/wayland-protocols/unstable/primary-selection/primary-selection-unstable-v1.xml \
        /usr/local/share/wayland-protocols/unstable/primary-selection/primary-selection-unstable-v1.xml
}

protocol_sources_linux_dmabuf_candidates() {
    local protocols_dir

    if [[ -n "${LINUX_DMABUF_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$LINUX_DMABUF_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml}" \
        /usr/share/wayland-protocols/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml \
        /usr/local/share/wayland-protocols/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml
}

protocol_sources_linux_drm_syncobj_candidates() {
    local protocols_dir

    if [[ -n "${LINUX_DRM_SYNCOBJ_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$LINUX_DRM_SYNCOBJ_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml}" \
        /usr/share/wayland-protocols/staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml \
        /usr/local/share/wayland-protocols/staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml
}

protocol_sources_fifo_candidates() {
    local protocols_dir

    if [[ -n "${FIFO_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$FIFO_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/staging/fifo/fifo-v1.xml}" \
        /usr/share/wayland-protocols/staging/fifo/fifo-v1.xml \
        /usr/local/share/wayland-protocols/staging/fifo/fifo-v1.xml
}

protocol_sources_commit_timing_candidates() {
    local protocols_dir

    if [[ -n "${COMMIT_TIMING_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$COMMIT_TIMING_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/staging/commit-timing/commit-timing-v1.xml}" \
        /usr/share/wayland-protocols/staging/commit-timing/commit-timing-v1.xml \
        /usr/local/share/wayland-protocols/staging/commit-timing/commit-timing-v1.xml
}

protocol_sources_content_type_candidates() {
    local protocols_dir

    if [[ -n "${CONTENT_TYPE_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$CONTENT_TYPE_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/staging/content-type/content-type-v1.xml}" \
        /usr/share/wayland-protocols/staging/content-type/content-type-v1.xml \
        /usr/local/share/wayland-protocols/staging/content-type/content-type-v1.xml
}

protocol_sources_alpha_modifier_candidates() {
    local protocols_dir

    if [[ -n "${ALPHA_MODIFIER_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$ALPHA_MODIFIER_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/staging/alpha-modifier/alpha-modifier-v1.xml}" \
        /usr/share/wayland-protocols/staging/alpha-modifier/alpha-modifier-v1.xml \
        /usr/local/share/wayland-protocols/staging/alpha-modifier/alpha-modifier-v1.xml
}

protocol_sources_tearing_control_candidates() {
    local protocols_dir

    if [[ -n "${TEARING_CONTROL_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$TEARING_CONTROL_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/staging/tearing-control/tearing-control-v1.xml}" \
        /usr/share/wayland-protocols/staging/tearing-control/tearing-control-v1.xml \
        /usr/local/share/wayland-protocols/staging/tearing-control/tearing-control-v1.xml
}

protocol_sources_color_representation_candidates() {
    local protocols_dir

    if [[ -n "${COLOR_REPRESENTATION_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$COLOR_REPRESENTATION_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/staging/color-representation/color-representation-v1.xml}" \
        /usr/share/wayland-protocols/staging/color-representation/color-representation-v1.xml \
        /usr/local/share/wayland-protocols/staging/color-representation/color-representation-v1.xml
}

protocol_sources_color_management_candidates() {
    local protocols_dir

    if [[ -n "${COLOR_MANAGEMENT_XML_SOURCE:-}" ]]; then
        printf '%s\n' "$COLOR_MANAGEMENT_XML_SOURCE"
        return 0
    fi

    protocols_dir="$(protocol_sources_pkg_config_variable wayland-protocols pkgdatadir)"

    printf '%s\n' \
        "${protocols_dir:+$protocols_dir/staging/color-management/color-management-v1.xml}" \
        /usr/share/wayland-protocols/staging/color-management/color-management-v1.xml \
        /usr/local/share/wayland-protocols/staging/color-management/color-management-v1.xml
}

protocol_sources_first_existing_file() {
    local path

    for path in "$@"; do
        [[ -n "$path" ]] || continue
        if [[ -f "$path" ]]; then
            printf '%s\n' "$path"
            return 0
        fi
    done

    return 1
}
