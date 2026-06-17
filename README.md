# WaylandClientKit

WaylandClientKit is a Swift 6 package for building native Wayland clients and
GUI framework infrastructure on Linux.

It exposes typed Swift APIs over Wayland client protocols for display lifecycle,
windows, input, text input, data transfer, cursors, desktop integration, output
facts, presentation feedback, and preview graphics submission.

## Toolkit Boundary

WaylandClientKit does not wrap Qt, GTK, Electron, SDL, or another application
toolkit.

It uses Linux and Wayland system libraries directly, then keeps raw protocol
handles, queues, file descriptors, unsafe lifetimes, and C interop behind Swift
APIs.

This package is intentionally below a GUI toolkit. Layout, widgets, styling,
accessibility semantics, scene management, application architecture, and renderer
selection belong in higher layers.

## Status

WaylandClientKit is pre-foundation. It is useful for experiments, GUI framework
development, compositor testing, and protocol validation, but source-breaking
changes are still possible.

`WaylandClient` is the main public product. Its public API is baseline/audit
tracked under the [compatibility policy](docs/compatibility-policy.md).

`WaylandGraphicsPreview` is a source-breaking preview product for graphics
submission experiments. It may change while the graphics path is validated
across real compositors.

Versioning is documented in [Versioning](docs/versioning.md).

## What It Supports

Current public coverage includes:

- display connection and owner-thread lifecycle
- xdg-shell windows, popups, dialogs, and subsurfaces
- software frame drawing, damage, regions, scale, and presentation feedback
- pointer, keyboard, touch, tablet, gestures, pointer capture, and pointer warp
- xkbcommon-backed key interpretation, compose, and dead-key text
- regular clipboard, primary selection, drag-and-drop, and drag icons
- text input through `zwp_text_input_v3`
- cursor themes, cursor-shape requests, custom cursors, and cursor animation
- desktop integration hooks for icons, idle inhibition, activation, system bell,
  shortcut inhibition, and toplevel drag
- output topology facts and wlroots output-management preview snapshots
- preview graphics APIs with software fallback reporting

The full protocol/status table lives in [Support Matrix](docs/support-matrix.md).

## What It Does Not Provide

WaylandClientKit does not provide a widget set, declarative view tree, layout
engine, styling system, accessibility model, scene model, retained renderer, or
public raw Wayland binding layer.

Raw Wayland, GBM, EGL, DRM, dmabuf, syncobj, and graphics file descriptor handles
are not public API.

## Quick Start

WaylandClientKit requires Swift 6.3.2 or newer.

```bash
nix develop
swift run wck tools toolchain-smoke
swift run wck bootstrap check
swift build --disable-index-store
swift run wayland-client-kit-smoke
```

If you are not using Nix, install the packages in
[Linux Dependencies](docs/linux-dependencies.md), then run the same `wck`
checks.

## Tiny Window

```swift
import WaylandClient

@main
struct TinyWaylandClient {
    static func main() async throws {
        try await WaylandDisplay.withConnection { display in
            let window = try await display.createTopLevelWindow()

            try await window.show { frame in
                frame.withXRGB8888Rows { _, pixels in
                    for index in 0..<pixels.count {
                        unsafe pixels[unchecked: index] = 0x0020_4060
                    }
                }
            }

            for await event in display.inputEvents.prefix(4) {
                print(event)
            }

            await window.close()
        }
    }
}
```

For the full walkthrough, see [Getting Started](docs/getting-started.md).

## Products

### `WaylandClient`

The main public product for windowing, input, data transfer, text input, cursors,
output facts, presentation feedback, and desktop integration.

### `WaylandGraphicsPreview`

A source-breaking preview product for renderer-facing experiments. Use it when
testing managed GPU paths, software fallback behavior, synchronization, pacing,
or graphics metadata.

## Repository Checks

The `wck` executable contains project checks and maintainer tooling.

Common commands:

```bash
swift run wck ci cheap
swift run wck ci check
swift run wck examples build
swift run wck protocols verify-generated
```

Checks cover protocol generation, shim verification, public API baselines, DocC,
import boundaries, unsafe-token allowlists, examples, unit tests, integration
tests, sanitizer runs, and live/headless smoke paths.

See [Tooling](docs/tooling.md) and [Protocol Generation](docs/generation.md) for
details.

## Documentation

- [Getting Started](docs/getting-started.md)
- [Which API Should I Use?](docs/which-api-should-i-use.md)
- [Support Matrix](docs/support-matrix.md)
- [Linux Dependencies](docs/linux-dependencies.md)
- [Protocol Generation](docs/generation.md)
- [Tooling](docs/tooling.md)
- [WaylandClient DocC](Sources/WaylandClient/WaylandClient.docc/WaylandClient.md)
- [WaylandGraphicsPreview DocC](Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc/WaylandGraphicsPreview.md)
- [Compatibility Policy](docs/compatibility-policy.md)
- [Versioning](docs/versioning.md)
- [Release Checklist](docs/release.md)

## Examples

Useful first examples:

- [WaylandClientKitDemo](Examples/WaylandClientKitDemo/main.swift)
- [FrameworkHostSmoke](Examples/FrameworkHostSmoke/main.swift)
- [TextInputSmoke](Examples/TextInputSmoke/main.swift)
- [DataTransferSmoke](Examples/DataTransferSmoke/main.swift)
- [PresentationFeedbackAnimation](Examples/PresentationFeedbackAnimation/main.swift)
- [OutputManagementSmoke](Examples/OutputManagementSmoke/main.swift)
- [GPUPreviewSmokeClient](Examples/GPUPreviewSmokeClient/main.swift)

Build every example with:

```bash
swift run wck examples build
```

## Compositor Evidence

Wayland behavior varies by compositor and advertised protocol support.
WaylandClientKit tracks live compositor evidence separately from unit tests.

See [Compositor Matrix](docs/compositor-matrix.md) for current evidence and
collection commands.

## Contributing

Read [Contributing](CONTRIBUTING.md), [Support](SUPPORT.md), and the
[Code of Conduct](CODE_OF_CONDUCT.md).

Keep changes protocol-shaped, small, documented, and verified. Public API changes
should update the relevant baseline, audit, docs, tests, and examples.

## Security

Do not open public issues for vulnerabilities. Follow [SECURITY.md](SECURITY.md).

## License

WaylandClientKit is licensed under the [Apache License 2.0](LICENSE).

Vendored protocol XML keeps upstream license and provenance notices intact.
Generated protocol artifacts should retain those upstream comments when they are
regenerated.
