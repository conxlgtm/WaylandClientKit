# Surface Regions And Damage

Use regions when compositor-facing surface shape matters. ``SurfaceRegion``
publishes logical rectangles for input and opacity. ``SurfaceDamageRegion``
publishes logical rectangles that changed between frames.

Use `setInputRegion(_:)` when only part of a managed surface should receive
pointer targeting from the compositor. Use `setOpaqueRegion(_:)` when
rectangles are fully opaque and the compositor can optimize composition. Pass a
``SurfaceFrameMetadata`` value with non-`nil` damage to a window, popup, or
subsurface `redraw` method when an already-shown surface changed only part of
its content.

## Capability Gate

Regions use `wl_compositor` region objects and the managed surface path. Damage
is part of core Wayland. WaylandClientKit validates damage against
the current ``SurfaceGeometry`` and maps logical rectangles to buffer
coordinates for the active scale.

Invalid rectangles and out-of-bounds damage are reported as typed client errors.
WaylandClientKit owns coordinate conversion and clipping. A `nil` metadata
damage value is the only full-frame representation.

## Example

See `SurfaceRegionSmoke` in `Examples/SurfaceRegionSmoke` and
`DamageRegionSmoke` in `Examples/DamageRegionSmoke`.
