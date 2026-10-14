# WaylandClientKit

WaylandClientKit provides typed Swift APIs for Wayland clients and GUI
frameworks on Linux, using the Wayland system libraries directly.

## Products

The project is in early development, and source-breaking changes are possible.

- `WaylandClient` covers windows, popups, dialogs, subsurfaces, software drawing,
  input, text input, data transfer, cursors, presentation feedback, and desktop
  and output integration.
- `WaylandGraphicsPreview` is a preview product for graphics submission
  experiments, with explicit software fallback reporting.

Both products are baseline and audit tracked under the
[compatibility policy](docs/compatibility-policy.md).

## Build And Run

Swift 6.4.0 or newer is required; the package uses Swift 6 language mode.

```bash
nix develop
swift run wck tools toolchain-smoke
swift run wck bootstrap check
swift build --disable-index-store
swift run wayland-client-kit-smoke
```

Nix selects the Swiftly toolchain and configures a compiler-specific SDK for
SwiftPM's default backend. Set `SWIFT_BIN` before entering the shell to override
the compiler.

Without Nix, install the packages in
[Linux Dependencies](docs/linux-dependencies.md) before building.
The smoke executable needs a Wayland session.

## Checks

```bash
swift run wck ci cheap
swift run wck ci required
swift run wck ci check
swift run wck examples build
swift run wck protocols verify-generated
swift run wck identity verify-generated
```

See [Tooling](docs/tooling.md) for check details and
[Protocol Generation](docs/generation.md) for generated files.

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

## Contributing And License

See [Contributing](CONTRIBUTING.md), [Support](SUPPORT.md), and the
[Code of Conduct](CODE_OF_CONDUCT.md). Report vulnerabilities privately according
to [Security](SECURITY.md).

Licensed under the [Apache License 2.0](LICENSE). Vendored protocol XML and
generated artifacts keep their upstream license and provenance notices.
