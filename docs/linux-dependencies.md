# Linux Dependencies

WaylandClientKit requires Swift 6.4.0 or newer. `swift run wck bootstrap check`
verifies Swift and Linux system dependencies. It does not install or switch
toolchains.

Set `SWIFT_BIN=/path/to/swift` for custom toolchain resolution. On Nix, provide
the override before entering `nix develop`.

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

Nix/NixOS support is declarative through `flake.nix`. Use `nix develop` for the
project development shell. It derives a Swift SDK/toolset from the selected
compiler and Nix platform, including glibc headers, start objects, linker, and
dynamic loader. Compiler-specific wrappers and a symlink-only Swift runtime
overlay live under `$XDG_CACHE_HOME/waylandclientkit/swift-sdk` (by default,
`~/.cache/waylandclientkit/swift-sdk`). SDK selection applies to ordinary
`swift build`, `run`, `test`, and `package` commands without installing a global SDK.
Runtime search paths are scoped to tool invocations and linked executables, not
exported through `LD_LIBRARY_PATH` to Git, hooks, or unrelated system tools.
Swift-native tools such as SwiftLint use the same scoped loader and the selected
toolchain's SourceKit library; script-based tool overrides keep their interpreter.

The initial compiler metadata probe currently emits a `libc not found` warning.
Keep it visible when reporting Nix validation. Debug/release linking and
Foundation child processes must still use the generated SDK's matching glibc
loader; the warning is not a reason to switch to the native backend.

The local SwiftPM runtime also reports `safeExec` signal 32/33 warnings. C
compilation against the current glibc 2.42 headers can report `__INT64_C` and
`__UINT64_C` macro redefinitions. Keep these diagnostics visible; the existing
test-only C-import warning policy is unchanged by the toolchain cutover.

Nix builds require unprivileged user/mount namespaces. SwiftPM runs in a child
mount namespace that supplies Nix coreutils at `/usr/bin` for Swift Build's
hardcoded resource-bundle `touch` task. Native `/dev`, `/proc`, and `/sys` access
is retained; the host filesystem and unrelated processes are not modified.

On openSUSE, upstream Swift SwiftPM may require a compatibility `libxml2.so.2`
that the distro `libxml2-16` package does not provide. Project Swift wrappers
load `$SWIFT_COMPAT_LIBS` when present, defaulting to
`$HOME/.local/share/swift-compat-libs`. Tools that invoke the Swift toolchain
directly must set `LD_LIBRARY_PATH` to include that directory or make the
compatibility library available in the toolchain runtime path.
