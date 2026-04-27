#!/usr/bin/env bash
set -euo pipefail

if ! command -v swift > /dev/null 2>&1; then
    echo "Swift 6.3.1 must already be installed and on PATH."
    exit 1
fi

sudo dnf install -y \
    wayland-devel \
    wayland-protocols-devel \
    pkgconf-pkg-config \
    libxkbcommon-devel \
    git \
    ripgrep \
    clang --skip-unavailable

swift --version
pkg-config --modversion wayland-client
command -v wayland-scanner

if [[ -f /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml ]]; then
    :
elif [[ -f /usr/share/qt6/wayland/protocols/xdg-shell/xdg-shell.xml ]]; then
    :
else
    echo "Missing xdg-shell.xml in both expected Fedora locations."
    exit 1
fi

echo "Fedora Wayland bootstrap checks passed."
