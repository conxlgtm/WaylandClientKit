# WaylandClientKit

WaylandClientKit is a Swift package for building Wayland client-side GUI
substrate code on Linux.

It gives Swift programs typed access to Wayland display and window lifecycle,
input, text input, data transfer, cursors, desktop integration, output facts,
presentation feedback, and source-breaking preview graphics submission.

Scope boundary: layout, widgets, styling, accessibility semantics, scene
management, and renderer selection belong in frameworks built above
WaylandClientKit.

## Status

WaylandClientKit is pre-foundation. It is useful for experiments, framework
development, and protocol validation, but source-breaking changes are still
possible.

`WaylandClient` is the main public product. Its public API is baseline/audit
tracked under the [compatibility policy](docs/compatibility-policy.md).

`WaylandGraphicsPreview` is preview API and may break source compatibility while
the graphics substrate proves itself on real compositors.

Versioning is documented in [Versioning](docs/versioning.md). Public-launch
status is tracked in [Public Readiness](docs/public-readiness.md).

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
- source-breaking preview graphics APIs with software fallback reporting

The full protocol/status table lives in [Support Matrix](docs/support-matrix.md).

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

## Documentation

- [Getting Started](docs/getting-started.md)
- [Which API Should I Use?](docs/which-api-should-i-use.md)
- [Support Matrix](docs/support-matrix.md)
- [Linux Dependencies](docs/linux-dependencies.md)
- [WaylandClient DocC](Sources/WaylandClient/WaylandClient.docc/WaylandClient.md)
- [WaylandGraphicsPreview DocC](Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc/WaylandGraphicsPreview.md)
- [Compatibility Policy](docs/compatibility-policy.md)
- [Versioning](docs/versioning.md)
- [Release Checklist](docs/release.md)
- [Public Readiness](docs/public-readiness.md)

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

## Contributing

Read [Contributing](CONTRIBUTING.md), [Support](SUPPORT.md), and the
[Code of Conduct](CODE_OF_CONDUCT.md). Keep changes protocol-shaped, small, and
verified.

## Security

Do not open public issues for vulnerabilities. Follow [SECURITY.md](SECURITY.md).

## License

WaylandClientKit is licensed under the [Apache License 2.0](LICENSE).

Vendored protocol XML keeps upstream license and provenance notices intact.
Generated protocol artifacts should retain those upstream comments when they are
regenerated.
