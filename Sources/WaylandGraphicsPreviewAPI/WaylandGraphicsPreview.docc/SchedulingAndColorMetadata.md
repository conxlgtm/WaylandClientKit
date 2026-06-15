# Scheduling And Color Metadata

``WaylandGraphicsFrameSchedule`` is the preview per-frame scheduling request for
graphics preview submissions.

Scheduling is compositor-mediated. Active runtime status means the requested
feature was applied to a submitted frame. Advertised status means only that a
protocol or capability was discovered.

## Scheduling

Use ``WaylandGraphicsFrameSchedule/synchronization`` for implicit, preferred
explicit, or required explicit synchronization policy. Use
``WaylandGraphicsFrameSchedule/pacing`` to request no pacing, FIFO, or
commit-timing with ``WaylandGraphicsPresentationTarget/default``.

The public schedule does not expose syncobj timelines, fences, or raw protocol
objects. Frameworks own animation policy; WaylandClientKit exposes timing facts
and commit requests.

## Color Metadata

``WaylandGraphicsFrameMetadata`` can carry content type, presentation hint,
alpha modifier, and color representation. Public color-description attachment is
deferred until WaylandClientKit exposes a managed image-description producer.
WaylandClientKit applies supported protocol metadata before commit and reports
missing support as runtime fallback facts. It does not perform tone mapping,
gamut conversion, ICC parsing, asset color policy, or renderer color-pipeline
work.

Use `ColorManagementSmoke` to inspect color capability facts and
`GraphicsPreviewColorMetadataSmoke` to submit a bounded metadata request.
