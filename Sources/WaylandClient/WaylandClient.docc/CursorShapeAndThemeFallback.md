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

WaylandClientKit currently provides built-in presets for default arrow, text,
pointer, crosshair, horizontal resize, vertical resize, and hidden cursors.
Diagonal resize cursors are intentionally not built in yet because portable
theme-name behavior still needs evidence across KDE, GNOME, Sway/wlroots, and
Weston.

Static software cursor images are supported through ``PointerCursorImage`` and
``PointerCursor/image(_:)``. Images use one XRGB8888 pixel array, a declared
pixel size, and a pixel-space hotspot that must be inside the image. WaylandClientKit
keeps the SHM buffer and raw cursor surface private.

Frameworks implementing client-side resize chrome can use custom cursor names
when they have theme-specific policy:

```swift
let topLeft = try? PointerCursor(name: "nw-resize")
let topRight = try? PointerCursor(name: "ne-resize")
let bottomLeft = try? PointerCursor(name: "sw-resize")
let bottomRight = try? PointerCursor(name: "se-resize")
```

Treat these names as best-effort theme requests. If a cursor cannot be resolved,
fall back to an existing built-in such as ``PointerCursor/crosshair`` or keep the
current cursor until the framework has compositor/theme evidence for a better
choice.

Animated cursor scheduling is intentionally deferred. WaylandClientKit has internal
animation state primitives, but no public owner-thread scheduler contract yet.
Use explicit cursor replacement for now.

## Capability Gate

Compositor cursor shapes require `wp_cursor_shape_manager_v1`.
Theme-backed and custom image cursors use managed cursor surfaces and
`wayland-cursor` support. Requests can still fail or fall back when a seat has
no pointer focus, a theme name cannot be resolved, or compositor policy rejects
the cursor path.

## Public APIs

- ``PointerCursor``
- ``PointerCursorImage``
- ``WaylandDisplay/setPointerCursor(_:)``
- ``CursorConfiguration``
- ``CursorRequestResult``

## Errors And Policy

WaylandClientKit owns cursor request routing, fallback attempts, and diagnostics.
Frameworks own cursor policy, hit testing, resize affordances, and deciding
which cursor to request for a given interaction.

## Examples

See `CursorPolicySmoke` in `Examples/CursorPolicySmoke` and
`CustomCursorSmoke` in `Examples/CustomCursorSmoke`.
