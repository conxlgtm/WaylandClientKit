# Getting Started

## 1. Install Dependencies

On Nix/NixOS, enter the project shell:

```bash
nix develop
```

On other Linux distributions, install [Linux Dependencies](linux-dependencies.md),
then check the environment:

```bash
swift run wck tools toolchain-smoke
swift run wck bootstrap check
```

WaylandClientKit requires Swift 6.4.0 or newer and uses Swift 6 language mode.

The Nix shell uses Swiftly's 6.4.0 distribution by default. To choose another
supported toolchain, run `SWIFT_BIN=/path/to/toolchain/usr/bin/swift nix develop`.
The compiler, Clang, formatter, symbol graphs, and generated Swift SDK all use
that toolchain.

The commands below use the default SwiftPM build backend with the generated SDK.
Do not add `--build-system native` or export a synthetic `SDKROOT`.

## 2. Build WaylandClientKit

```bash
swift build --disable-index-store
```

Run the local CI gate:

```bash
swift run wck ci check
```

## 3. Run The Smoke Executable

Under a Wayland session:

```bash
swift run wayland-client-kit-smoke
```

Run additional live checks:

```bash
swift run wck smoke live
```

If no desktop compositor is available but Weston is installed, run:

```bash
swift run wck smoke headless -- wck smoke integration
```

## 4. Create A Tiny Client

Create a Swift executable package that depends on WaylandClientKit:

```swift
import WaylandClient

@main
struct TinyWaylandClient {
    static func main() async throws {
        try await WaylandDisplay.withConnection(
            applicationID: "org.example.MyApp"
        ) { display in
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

`SoftwareFrame.withXRGB8888Rows` borrows exactly `frame.width` pixels per row.
Row spans exclude padding and extra backing bytes. A thrown drawing error ends
the borrow.

`WaylandDisplay.withConnection` requires an application ID, discovers capabilities,
and starts the owner-thread event loop. Before returning your body's result or
error, it awaits display close and all window-close observers. This also applies
when the body is cancelled; cleanup runs in the same task.

`Window.show` waits for the initial xdg configure before mapping the window with
its first buffer. Use `Window.redraw` for later presentations. Request another
frame with `Window.requestRedraw()`, then redraw when your app is ready.

## 5. Read Input And Events

Use `display.events` for the complete ordered feed of display/window/output,
input, text-input, data-transfer, presentation, and diagnostic events. It is the
only stream that preserves ordering across event families.

Specialized streams such as `display.inputEvents`,
`display.textInputEvents`, `display.dataTransferEvents`,
`display.diagnostics`, and `window.presentationEvents` remain useful when an
application needs only one family. They preserve order within that family.

## 6. Close Cleanly

Close windows you own with `await window.close()`. Leaving the
`WaylandDisplay.withConnection` body closes the display and retires managed
resources. Applications can handle compositor errors and absent optional
protocols as runtime conditions.

## Next Example

[Which API Should I Use?](which-api-should-i-use.md) links each feature to a
runnable example.
