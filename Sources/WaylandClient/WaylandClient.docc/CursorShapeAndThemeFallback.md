# Cursor Shape And Theme Fallback

``PointerCursor`` requests can use compositor-managed cursor-shape support when
the compositor advertises it and the requested cursor maps to a protocol shape.

When cursor-shape is unavailable or a cursor name has no protocol mapping,
WaylandClientKit falls back to the configured wayland-cursor theme through
``CursorConfiguration``. Hidden cursors still use the Wayland nil-surface cursor
request.

Cursor diagnostics are reported through the input diagnostic path.

``CursorConfiguration/scalePolicy`` controls how theme cursor size is selected.
`PointerCursorScalePolicy.fixed` uses the configured base size.
`PointerCursorScalePolicy.matchFocusedOutput` scales the theme cursor for the
focused surface's outputs. `PointerCursorScalePolicy.maximumOutputScale` uses
the largest known output scale.

Built-in presets cover the default arrow, text, pointer, crosshair, horizontal
and vertical resize, and hidden cursors. Diagonal resize remains theme-specific.

Static software cursor images are supported through ``PointerCursorImage`` and
``PointerCursor/image(_:)``. Images use one XRGB8888 pixel array, a declared
pixel size, and a pixel-space hotspot that must be inside the image. WaylandClientKit
keeps the SHM buffer and raw cursor surface private.

Animated software cursor images are supported through ``PointerCursorFrame``,
``AnimatedPointerCursor``, and ``PointerCursor/animated(_:)``. Each frame uses
the same XRGB8888 image format and hotspot validation as a static custom cursor
image. Frame durations must be positive, and empty animations are rejected before
any cursor request is sent.

Animation starts when the animated cursor becomes current. Replacing it stops
the animation; pointer leave pauses it. Seat removal and display close release
its buffers.

Frameworks implementing client-side resize chrome can use custom cursor names
when they have theme-specific policy:

```swift
let topLeft = try? PointerCursor(name: "nw-resize")
let topRight = try? PointerCursor(name: "ne-resize")
let bottomLeft = try? PointerCursor(name: "sw-resize")
let bottomRight = try? PointerCursor(name: "se-resize")
```

Theme names are best-effort. An unresolved name can fall back to a built-in such
as ``PointerCursor/crosshair`` or leave the current cursor unchanged.

## Capability Gate

Compositor cursor shapes require `wp_cursor_shape_manager_v1`.
Theme-backed and custom image cursors use managed cursor surfaces and
`wayland-cursor` support. Requests can still fail or fall back when a seat has
no pointer focus, a theme name cannot be resolved, or compositor policy rejects
the cursor path.

WaylandClientKit owns request routing, fallback attempts, and diagnostics.
Frameworks own hit testing and cursor policy.

## Examples

See `CursorPolicySmoke`, `CustomCursorSmoke`, and `CursorAnimationSmoke` in
`Examples/`.
