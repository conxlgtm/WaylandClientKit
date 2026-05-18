#!/usr/bin/env bash

swift_wayland_prepend_ld_library_path() {
    local directory="$1"

    [[ -d "$directory" ]] || return 0
    if [[ ":${LD_LIBRARY_PATH:-}:" == *":$directory:"* ]]; then
        return 0
    fi

    if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
        export LD_LIBRARY_PATH="$directory:$LD_LIBRARY_PATH"
    else
        export LD_LIBRARY_PATH="$directory"
    fi
}

swift_wayland_configure_swift_compat_libraries() {
    local compat_directory="${SWIFT_COMPAT_LIBS:-$HOME/.local/share/swift-compat-libs}"

    swift_wayland_prepend_ld_library_path "$compat_directory"
}

swift_wayland_configure_swift_compat_libraries
