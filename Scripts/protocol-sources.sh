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
