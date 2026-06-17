# Linux Dependencies

WaylandClientKit requires Swift 6.3.2 or newer. `swift run wck bootstrap check`
verifies Swift and Linux system dependencies. It does not install or switch
toolchains.

Set `SWIFT_BIN=/path/to/swift` for custom toolchain resolution.

Current CI validates dynamic glibc Linux on Ubuntu Noble with shared libraries
resolved through `pkg-config`. Musl, static Linux SDK builds, and static linking
are not part of the current support contract.

## Capability Checks

The build dependency source of truth is the system capability surface:

- Swift 6.3.2 or newer
- `clang`
- `pkg-config`
- `pkg-config --exists egl`
- `pkg-config --exists gbm`
- `pkg-config --exists glesv2`
- `pkg-config --exists libdrm`
- `pkg-config --exists wayland-client`
- `pkg-config --exists wayland-cursor`
- `pkg-config --exists xkbcommon`

Maintainers regenerating protocol artifacts also need:

- `wayland-scanner`
- `pkg-config --exists wayland-protocols`
- `wayland.xml`
- `stable/xdg-shell/xdg-shell.xml`

## Package Managers

| Family | Packages |
| --- | --- |
| Debian/Ubuntu | `clang git libdrm-dev libegl-dev libgbm-dev libgles-dev libwayland-bin libwayland-dev libxkbcommon-dev pkg-config ripgrep wayland-protocols` |
| Fedora/RHEL-like | `clang git libdrm-devel mesa-libEGL-devel mesa-libgbm-devel mesa-libGLES-devel wayland-devel wayland-protocols-devel libxkbcommon-devel pkgconf-pkg-config ripgrep` |
| Arch/Manjaro | `clang git libdrm mesa wayland wayland-protocols libxkbcommon pkgconf ripgrep` |
| openSUSE | `clang git libdrm-devel Mesa-libEGL-devel libgbm-devel Mesa-libGLESv2-devel wayland-devel wayland-protocols-devel libxkbcommon-devel pkgconf-pkg-config ripgrep` |
| Alpine | `clang git libdrm-dev mesa-dev wayland-dev wayland-protocols libxkbcommon-dev pkgconf ripgrep` |
| Gentoo | `sys-devel/clang dev-vcs/git x11-libs/libdrm media-libs/mesa dev-libs/wayland dev-libs/wayland-protocols dev-util/wayland-scanner x11-libs/libxkbcommon virtual/pkgconfig sys-apps/ripgrep` |
| Nix/NixOS | `nix develop` |

Alpine package installation is mapped for Wayland dependencies, but Swift
toolchain availability may require separate setup. The Alpine row is a
dependency lookup aid, not a Musl support claim.

Nix/NixOS support is declarative through `flake.nix`. Use `nix develop` for the
project development shell.

On openSUSE, Swift 6.3.2 SwiftPM may require a compatibility `libxml2.so.2`
that the distro `libxml2-16` package does not provide. Project Swift wrappers
load `$SWIFT_COMPAT_LIBS` when present, defaulting to
`$HOME/.local/share/swift-compat-libs`. Tools that invoke the Swift toolchain
directly must set `LD_LIBRARY_PATH` to include that directory or make the
compatibility library available in the toolchain runtime path.
