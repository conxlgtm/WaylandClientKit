# Graphics Runtime Path

``WaylandGraphicsRuntimePath`` reports what the preview path actually knows or
did. It distinguishes protocol advertisement from surface-specific setup and
from active submission.

## Status Vocabulary

``WaylandGraphicsRuntimeStatus`` uses:

- `unavailable`: no public or runtime support exists for this component.
- `pending`: discovery has not completed.
- `advertised`: a compositor advertised a relevant global or capability.
- `configured`: SwiftWayland configured the component for this surface.
- `active`: a submitted frame actually used this component.
- `failed`: require-GPU or require-feature policy failed with a typed reason.
- `fallback`: the frame used software fallback with a typed reason.

## Components

The path includes backing, dmabuf advertisement, surface feedback, render-node
selection, GBM, EGL, dmabuf import, buffer lifecycle, explicit sync, pacing,
metadata, and presentation feedback.

Do not treat `dmabuf.advertised` as active GPU. Managed GPU is active only after
a real GPU-backed frame submission succeeds and the result reports active
backing.

## Public APIs

- ``WaylandGraphicsRuntimePath``
- ``WaylandGraphicsRuntimeStatus``
- ``WaylandGraphicsFrameResult/runtimePath``
- ``WaylandGraphicsFrameResult/backing``

## Example

`GPUPreviewSmokeClient` prints a matrix-friendly runtime-path report for the
current compositor.
