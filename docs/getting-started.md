# Getting Started

This path builds one tiny Wayland client and points you at the next examples to
read.

## 1. Install Dependencies

On Nix/NixOS, enter the project shell:

```bash
nix develop
```

On other Linux distributions, install the packages listed in
[Linux Dependencies](linux-dependencies.md), then verify the
environment:

```bash
swift run wck tools toolchain-smoke
swift run wck bootstrap check
```

WaylandClientKit currently requires Swift 6.3.2 or newer.

## 2. Build WaylandClientKit

```bash
swift build --disable-index-store
```

Maintainers can run the same normal branch gate that CI uses:

```bash
swift run wck ci check
```

## 3. Run The Smoke Executable

Under a Wayland session:

```bash
swift run wayland-client-kit-smoke
```

For the broader live smoke path:

```bash
swift run wck smoke live
```

If no desktop compositor is available but Weston is installed, run:

```bash
swift run wck smoke headless -- wck smoke integration
```

## 4. Create A Tiny Client

Create a new Swift executable package that depends on WaylandClientKit, or add this
shape to an existing package target:

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

            try await window.requestRedraw()
            try await window.redraw { frame in
                frame.withXRGB8888Rows { row, pixels in
                    for index in 0..<pixels.count {
                        let stripe = UInt32((row + index) & 0x3F)
                        unsafe pixels[unchecked: index] = 0x0040_4000 | (stripe << 8)
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

`WaylandDisplay.withConnection` opens the display, discovers advertised
capabilities, starts the owner-thread event loop, runs your async body, and
closes the display even if the body throws.

`Window.show` is the first buffer-backed presentation for a managed window. It
waits for the initial xdg configure before mapping the window. `Window.redraw`
is for subsequent presentations after the window already has a configured
surface. If you need another frame, call `Window.requestRedraw()` and redraw
when your app policy decides to produce it.

## 5. Read Input And Events

Use `display.inputEvents` for pointer, keyboard, touch, relative pointer, and
constraint lifecycle events. Use `display.events` for display/window/output
lifecycle, `display.dataTransferEvents` for clipboard and drag lifecycles, and
`display.diagnostics` for nonfatal diagnostics such as event overflow.

WaylandClientKit preserves Wayland identities and typed events for application
and framework routing.

## 6. Close Cleanly

Close windows you own with `await window.close()`. Leaving the
`WaylandDisplay.withConnection` body closes the display and retires managed
resources. Treat compositor errors and missing optional protocols as normal
runtime facts, not as proof that the client has become unusable.

## Next Examples

- [WaylandClientKitDemo](../Examples/WaylandClientKitDemo/main.swift) for a simple
  drawing and input loop.
- [FrameworkHostSmoke](../Examples/FrameworkHostSmoke/main.swift) for a small
  framework-host style loop above `WaylandClient`.
- [SessionStateSmoke](../Examples/SessionStateSmoke/main.swift) for saving and
  restoring app-owned window facts with `XDG_STATE_HOME`.
- [PresentationFeedbackAnimation](../Examples/PresentationFeedbackAnimation/main.swift)
  for frame callbacks and presentation feedback.
- [TextInputSmoke](../Examples/TextInputSmoke/main.swift) for compositor IME
  text input.
- [DataTransferSmoke](../Examples/DataTransferSmoke/main.swift) for clipboard
  and drag-and-drop paths.
- [GPUPreviewSmokeClient](../Examples/GPUPreviewSmokeClient/main.swift) for the
  preview graphics API.
