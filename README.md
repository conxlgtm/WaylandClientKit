# WaylandClientKit

WaylandClientKit is a Swift 6 package for building native Wayland client
infrastructure on Linux.

It provides typed Swift APIs over Wayland client protocols for display and
window lifecycle, input, text input, data transfer, cursors, desktop integration,
output facts, presentation feedback, and experimental graphics submission.

WaylandClientKit is not a widget toolkit, application framework, renderer, or
SwiftUI clone. It is the lower platform layer that a Swift-native GUI framework
can build on.

## Why This Exists

Most Swift GUI work on Linux has to start by adopting an existing application
toolkit or runtime such as Qt, GTK, Electron, SDL, or a web view. Those options
are useful and mature, but they also bring their own object models, event loops,
rendering policies, widget systems, and framework assumptions.

WaylandClientKit takes a different approach. It exposes Wayland client behavior
directly to Swift, while keeping raw Wayland handles, C interop details, file
descriptors, queues, unsafe lifetime rules, and protocol plumbing behind typed
Swift APIs.

The goal is to make it possible to build higher-level Swift GUI frameworks on
Linux without first inheriting another GUI toolkit.

Higher-level concerns are intentionally out of scope here:

- layout
- widgets
- styling
- accessibility semantics
- scene management
- renderer selection
- application architecture

Those belong in frameworks built above WaylandClientKit.

## Status

WaylandClientKit is pre-foundation.

It is useful for experiments, framework development, compositor testing, and
protocol validation, but source-breaking changes are still possible.

`WaylandClient` is the main public product. Its public API is baseline/audit
tracked under the [compatibility policy](docs/compatibility-policy.md).

`WaylandGraphicsPreview` is a source-breaking preview product for graphics
submission experiments. It may change while the graphics substrate is proven
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
- source-breaking preview graphics APIs with software fallback reporting

The full protocol/status table lives in [Support Matrix](docs/support-matrix.md).

## What It Does Not Provide

WaylandClientKit does not provide:

- a widget set
- a declarative view system
- layout primitives
- styling or theming policy
- an accessibility model
- a scene/document model
- a retained renderer
- a public raw Wayland binding layer
- public GBM, EGL, DRM, dmabuf, syncobj, or file descriptor graphics handles

The public API is intended to be framework-facing rather than toolkit-facing.
Applications can use it directly, but the main design target is code that wants
to build a Swift GUI framework above Wayland.

## Toolkit Dependencies

WaylandClientKit does not depend on Qt, GTK, Electron, SDL, or another
application toolkit.

It does use Linux/Wayland system libraries where appropriate, including Wayland
client libraries, xkbcommon, cursor support, and optional graphics-related
libraries for preview graphics paths. These are platform interfaces, not a
borrowed GUI framework.

See [Linux Dependencies](docs/linux-dependencies.md) for the current package
requirements.

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

The main public product.

Use this when building clients, experiments, framework prototypes, or higher
level GUI infrastructure that needs typed access to Wayland windowing, input,
data transfer, text input, cursor, output, and presentation behavior.

### `WaylandGraphicsPreview`

A source-breaking preview product for graphics submission experiments.

Use this only when testing or prototyping renderer-facing behavior. Its API may
change while managed GPU, software fallback, synchronization, pacing, and
metadata behavior are validated across compositors.

## Repository Tooling

The `wck` executable contains project checks and maintainer tooling for:

- bootstrap validation
- protocol generation and generated-artifact verification
- shim verification
- public API baseline verification
- DocC verification
- import-boundary checks
- unsafe-token allowlist checks
- example builds
- unit, integration, sanitizer, and smoke checks

Common commands:

```bash
swift run wck ci cheap
swift run wck ci check
swift run wck examples build
swift run wck protocols verify-generated
```

See [Tooling](docs/tooling.md) and [Protocol Generation](docs/generation.md)
for details.

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

## Compositor Evidence

Wayland behavior varies by compositor and by advertised protocol support.
WaylandClientKit tracks live compositor evidence separately from unit tests.

See [Compositor Matrix](docs/compositor-matrix.md) for current evidence and
collection commands.

## Contributing

Read [Contributing](CONTRIBUTING.md), [Support](SUPPORT.md), and the
[Code of Conduct](CODE_OF_CONDUCT.md).

Keep changes protocol-shaped, small, documented, and verified. Public API
changes should update the relevant baseline, audit, docs, tests, and examples.

## Security

Do not open public issues for vulnerabilities. Follow [SECURITY.md](SECURITY.md).

## License

WaylandClientKit is licensed under the [Apache License 2.0](LICENSE).

Vendored protocol XML keeps upstream license and provenance notices intact.
Generated protocol artifacts should retain those upstream comments when they are
regenerated.
