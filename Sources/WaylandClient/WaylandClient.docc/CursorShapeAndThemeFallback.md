# Cursor Shape And Theme Fallback

``PointerCursor`` requests can use compositor-managed cursor-shape support when
the compositor advertises it and the requested cursor maps to a protocol shape.

When cursor-shape is unavailable or a cursor name has no protocol mapping,
SwiftWayland falls back to the configured wayland-cursor theme through
``CursorConfiguration``. Hidden cursors still use the Wayland nil-surface cursor
request.

Cursor diagnostics are reported through the input diagnostic path.

SwiftWayland currently provides built-in presets for default arrow, text,
pointer, crosshair, horizontal resize, vertical resize, and hidden cursors.
Diagonal resize cursors are intentionally not built in yet because portable
theme-name behavior still needs evidence across KDE, GNOME, Sway/wlroots, and
Weston.

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
