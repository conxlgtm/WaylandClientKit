# Cursor Shape And Theme Fallback

``PointerCursor`` requests can use compositor-managed cursor-shape support when
the compositor advertises it and the requested cursor maps to a protocol shape.

When cursor-shape is unavailable or a cursor name has no protocol mapping,
SwiftWayland falls back to the configured wayland-cursor theme through
``CursorConfiguration``. Hidden cursors still use the Wayland nil-surface cursor
request.

Cursor diagnostics are reported through the input diagnostic path.
