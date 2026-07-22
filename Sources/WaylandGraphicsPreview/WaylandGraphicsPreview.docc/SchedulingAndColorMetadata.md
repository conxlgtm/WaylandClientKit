# Scheduling And Color Metadata

``WaylandGraphicsFrameSchedule`` carries per-frame scheduling requests.

Scheduling is compositor-mediated. Active runtime status means the requested
feature was applied to a submitted frame. Advertised status means only that a
protocol or capability was discovered.

## Scheduling

Use ``WaylandGraphicsFrameSchedule/synchronization`` for implicit, preferred
explicit, or required explicit synchronization policy. Use
``WaylandGraphicsFrameSchedule/pacing`` to request no pacing, FIFO, or
commit-timing with WaylandClientKit's preview default target.

The public schedule exposes timing facts and commit requests, not timelines,
fences, or protocol objects. Frameworks own animation policy.

## Color Metadata

``WaylandGraphicsFrameMetadata`` can carry content type, presentation hint,
alpha modifier, and color representation. Public color-description attachment is
deferred until WaylandClientKit exposes a managed image-description producer.
Supported metadata is applied before commit; missing support becomes a runtime
fallback fact. Tone mapping, gamut conversion, ICC parsing, and renderer color
policy remain outside the package.

Use `ColorManagementSmoke` to inspect color capability facts and
`GraphicsPreviewColorMetadataSmoke` to submit a bounded metadata request.
