# WaylandClientKit

WaylandClientKit is a Swift 6 package for native Wayland clients and GUI
framework infrastructure on Linux. It uses Wayland system libraries directly
and keeps protocol handles, file descriptors, unsafe lifetimes, and C interop
behind typed Swift APIs.

## Status And Products

WaylandClientKit is pre-foundation, so source-breaking changes are possible.

- `WaylandClient` is the public product for windows, input, text input, data
  transfer, cursors, output facts, presentation feedback, and desktop
  integration.
- `WaylandGraphicsPreview` is a source-breaking preview product for graphics
  submission experiments.

Both products are baseline and audit tracked under the
[compatibility policy](docs/compatibility-policy.md). Versioning is documented
in [Versioning](docs/versioning.md).

## Scope

Current public coverage includes:

- display, window, popup, dialog, and subsurface lifecycle
- software drawing, damage, scale, regions, and presentation feedback
- pointer, keyboard, touch, tablet, gesture, cursor, and text input
- clipboard, primary selection, and drag-and-drop
- desktop and output integration
- preview GPU submission with explicit software fallback reporting

See the [Support Matrix](docs/support-matrix.md) for protocol-level status.

WaylandClientKit does not provide widgets, layout, styling, accessibility
semantics, scene management, application architecture, or renderer selection.
It does not expose public raw Wayland, GBM, EGL, or DRM objects; borrowed file
descriptor integers; raw pointers; or unsafe implementation handles.

## Build And Run

Swift 6.3.2 or newer is required.

```bash
nix develop
swift run wck tools toolchain-smoke
swift run wck bootstrap check
swift build --disable-index-store
swift run wayland-client-kit-smoke
```

Without Nix, install the packages in
[Linux Dependencies](docs/linux-dependencies.md) before running the checks.
The smoke executable requires a Wayland session. For a first client, follow
[Getting Started](docs/getting-started.md).

## Repository Checks

```bash
swift run wck ci cheap
swift run wck ci required
swift run wck ci check
swift run wck examples build
swift run wck protocols verify-generated
swift run wck identity verify-generated
```

`ci cheap` runs static checks. `ci required` adds the public API baseline,
strict build, unit tests, external integration packages, and the expected-failure
graphics policy client. `ci check` also verifies Markdown and DocC.

See [Tooling](docs/tooling.md) and
[Protocol Generation](docs/generation.md) for command ownership and generated
files.

## Documentation

- [Getting Started](docs/getting-started.md)
- [Which API Should I Use?](docs/which-api-should-i-use.md)
- [Support Matrix](docs/support-matrix.md)
- [WaylandClient DocC](Sources/WaylandClient/WaylandClient.docc/WaylandClient.md)
- [WaylandGraphicsPreview DocC](Sources/WaylandGraphicsPreview/WaylandGraphicsPreview.docc/WaylandGraphicsPreview.md)
- [Compositor Matrix](docs/compositor-matrix.md)
- [Release Checklist](docs/release.md)

Examples are separate Swift package targets. Run one from the repository root:

```bash
swift run --package-path Examples WaylandClientKitDemo
```

The [API chooser](docs/which-api-should-i-use.md) links features to examples.
Build every example with `swift run wck examples build`.

## Policies

Read [Contributing](CONTRIBUTING.md), [Support](SUPPORT.md), and the
[Code of Conduct](CODE_OF_CONDUCT.md). Report vulnerabilities according to
[Security](SECURITY.md), not through public issues.

WaylandClientKit is licensed under the [Apache License 2.0](LICENSE). Vendored
protocol XML and generated artifacts retain upstream license and provenance
notices.
