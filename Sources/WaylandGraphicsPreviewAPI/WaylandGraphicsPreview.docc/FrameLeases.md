# Frame Leases

``WaylandGraphicsFrameLease`` is the single-use permission to submit one frame
through a ``WaylandGraphicsWindowBacking``.

## Lifecycle

Call ``WaylandGraphicsWindowBacking/nextFrame()`` to obtain a lease. Inspect
``WaylandGraphicsFrameLease/contract`` before rendering; it contains the current
surface generation, authoritative geometry, external-buffer candidate facts, and
synchronization availability for the frame. External-buffer candidate facts
include selected format, modifier, alpha interpretation, scanout preference, and
render-node device identity bytes for renderer-side allocation.

Submit the lease once with ``WaylandGraphicsFrameLease/submit(_:)``,
``WaylandGraphicsFrameLease/submitSoftware(metadata:_:)``, or by reserving a
registered external buffer with
``WaylandGraphicsFrameLease/reserveExternalBuffer(_:)`` and submitting the
returned render lease. Cancel the frame lease with
``WaylandGraphicsFrameLease/cancel()`` when no frame will be produced.

A backing allows only one active lease. A submitted or cancelled lease cannot be
submitted again. Closing the backing makes future lease operations fail with a
typed error.

## Software, Clear, And External Frames

``WaylandGraphicsSubmittedFrame/clearColor(_:)`` submits a renderer-neutral clear
frame. On active managed GPU backing, the clear is rendered through internal GPU
preview code. On software backing or fallback, WaylandClientKit fills a
`SoftwareFrame`.

External-buffer submission registers renderer-owned descriptors, reserves
registered buffers, submits render leases, and awaits release receipts. The
renderer owns allocation and rendering; WCK owns import, commit, release
tracking, and reuse gating.

Use ``WaylandGraphicsFrameMetadata`` and ``WaylandGraphicsDamageRegion`` to
describe optional metadata and logical damage. WaylandClientKit validates metadata
and damage before consuming the lease for commit work.

## Errors And Policy

WaylandClientKit owns lease state, retry behavior after pre-commit failures,
post-commit terminal state, and buffer release/reuse. Frameworks own frame
scheduling and whether a failure should retry, fall back, or close the view.

A frame contract generation changes when WCK observes different surface geometry.
Callers should discard work produced for stale geometry and request another frame
instead of forcing old-size content through the current lease.
