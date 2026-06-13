# Surface Regions And Damage

Use regions when compositor-facing surface shape matters. ``SurfaceRegion``
publishes logical rectangles for input and opacity. ``SurfaceDamageRegion``
publishes logical rectangles that changed between frames.

## When To Use This

Use ``Window/setInputRegion(_:)`` when only part of a window should receive
pointer targeting from the compositor. Use ``Window/setOpaqueRegion(_:)`` when
rectangles are fully opaque and the compositor can optimize composition. Use
``Window/redraw(damage:_:)`` when an already-shown window only changed part of
its surface.

## Capability Gate

Regions use `wl_compositor` region objects and the managed surface path. Damage
does not require an optional protocol, but WaylandClientKit validates damage against
the current ``SurfaceGeometry`` and maps logical rectangles to buffer
coordinates for the active scale.

## Public APIs

- ``SurfaceRegion``
- ``SurfaceDamageRegion``
- ``Window/setInputRegion(_:)``
- ``Window/setOpaqueRegion(_:)``
- ``Window/show(damage:timeoutMilliseconds:_:)``
- ``Window/redraw(damage:_:)``

## Errors And Policy

Invalid rectangles and out-of-bounds damage are reported as typed client errors.
WaylandClientKit owns coordinate conversion, clipping, and the first-frame full
damage rule. Frameworks own hit testing, occlusion policy, and deciding which
widgets or scene nodes caused a dirty region.

## Example

See `SurfaceRegionSmoke` in `Examples/SurfaceRegionSmoke` and
`DamageRegionSmoke` in `Examples/DamageRegionSmoke`.
