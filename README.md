# WaylandClientKit

Typed Swift APIs for Wayland clients on Linux.

- `WaylandClient`: windows, software drawing, input, and desktop integration.
- `WaylandGraphicsPreview`: graphics submission with software fallback reporting.

The APIs may change during early development. See the
[compatibility policy](docs/compatibility-policy.md) and [support matrix](docs/support-matrix.md).

## Build And Run

Swift 6.4.0 or newer is required; the package uses Swift 6 language mode.

```bash
nix develop
swift build --disable-index-store
swift run wayland-client-kit-smoke
swift run wck ci check
```

The smoke executable needs a Wayland session.
For setup without Nix, see [Linux Dependencies](docs/linux-dependencies.md).

## Documentation

- [Getting Started](docs/getting-started.md) · [Which API Should I Use?](docs/which-api-should-i-use.md)
- [WaylandClient DocC](Sources/WaylandClient/WaylandClient.docc/WaylandClient.md) · [WaylandGraphicsPreview DocC](Sources/WaylandGraphicsPreview/WaylandGraphicsPreview.docc/WaylandGraphicsPreview.md)
- [Tooling](docs/tooling.md) · [Protocol Generation](docs/generation.md)
- [Compositor Matrix](docs/compositor-matrix.md) · [Release Checklist](docs/release.md)

[Contributing](CONTRIBUTING.md) · [Support](SUPPORT.md) ·
[Code of Conduct](CODE_OF_CONDUCT.md) · [Security](SECURITY.md)

Licensed under the [Apache License 2.0](LICENSE). Vendored protocol XML and
generated artifacts keep their upstream license and provenance notices.
