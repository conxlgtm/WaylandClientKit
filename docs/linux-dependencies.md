# Linux Dependencies

WaylandClientKit requires Swift 6.4.0 or newer. `swift run wck bootstrap check`
verifies Swift and Linux system dependencies. It does not install or switch
toolchains.

To choose a compiler, set `SWIFT_BIN=/path/to/swift`. On Nix, set it before
running `nix develop`.

Current CI validates dynamic glibc Linux on Ubuntu Noble with shared libraries
resolved through `pkg-config`. Musl, static Linux SDK builds, and static linking
are not part of the current support contract.

## Capability Checks

A supported build requires these capabilities:

- Swift 6.4.0 or newer
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

Run `nix develop` to enter the Nix/NixOS development shell defined in `flake.nix`.
The shell builds a Swift SDK/toolset for the selected compiler and Nix platform,
including glibc headers, start objects, the linker, and the dynamic loader.
Compiler wrappers and a symlink-only Swift runtime overlay are cached under
`$XDG_CACHE_HOME/waylandclientkit/swift-sdk` (by default,
`~/.cache/waylandclientkit/swift-sdk`). The shell passes SDK selection to
`swift build`, `run`, `test`, and `package`; a global SDK installation is not
required.

Runtime search paths apply to each tool invocation and linked executable.
Git, hooks, and other system tools keep their host environment without a global
`LD_LIBRARY_PATH` override. Swift-native tools such as SwiftLint use the same
loader and the selected toolchain's SourceKit library. Script overrides use
their own interpreters.

The initial compiler metadata probe emits a `libc not found` warning.
Include it in Nix validation reports. Debug and release linking, along with
Foundation child processes, must use the generated SDK's matching glibc loader.
Keep the default build backend when investigating this warning.

Local SwiftPM runs also report `safeExec` signal 32/33 warnings. C compilation
against glibc 2.42 headers can report `__INT64_C` and `__UINT64_C` macro
redefinitions. Include these diagnostics in validation reports. The existing
test-only C-import warning policy still applies.

Nix builds require unprivileged user/mount namespaces. SwiftPM runs in a child
mount namespace with Nix coreutils at `/usr/bin` for Swift Build's hardcoded
resource-bundle `touch` task. It keeps native access to `/dev`, `/proc`, and `/sys`
and leaves the host filesystem and unrelated processes unchanged.

On openSUSE, upstream SwiftPM may need a compatibility `libxml2.so.2`
that the distro `libxml2-16` package does not provide. Project Swift wrappers
load `$SWIFT_COMPAT_LIBS` when present, defaulting to
`$HOME/.local/share/swift-compat-libs`. Tools that invoke the Swift toolchain
directly must set `LD_LIBRARY_PATH` to include that directory or make the
compatibility library available in the toolchain runtime path.
