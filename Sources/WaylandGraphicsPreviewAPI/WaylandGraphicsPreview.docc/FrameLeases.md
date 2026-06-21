# Frame Leases

``WaylandGraphicsFrameLease`` is the single-use permission to submit one frame
through a ``WaylandGraphicsWindowBacking``.

## Lifecycle

Call ``WaylandGraphicsWindowBacking/nextFrame()`` to obtain a lease. Inspect
``WaylandGraphicsFrameLease/contract`` before rendering; it contains the current
surface generation, authoritative geometry, external-buffer candidate facts, and
synchronization availability for the frame.

Submit the lease once with ``WaylandGraphicsFrameLease/submit(_:)`` or
``WaylandGraphicsFrameLease/submitSoftware(metadata:_:)``. Cancel the frame
lease with ``WaylandGraphicsFrameLease/cancel()`` when no frame will be
produced.

A backing allows only one active lease. A submitted or cancelled lease cannot be
submitted again. Closing the backing makes future lease operations fail with a
typed error.

## Software And Clear Frames

``WaylandGraphicsSubmittedFrame/clearColor(_:)`` submits a renderer-neutral clear
frame. On active managed GPU backing, the clear is rendered through internal GPU
preview code. On software backing or fallback, WaylandClientKit fills a
`SoftwareFrame`.

Package-scoped external-buffer helpers register renderer-owned descriptors,
reserve registered buffers, submit render leases, and await release receipts.
That path exists to prove renderer-owned dmabuf presentation without normal
CPU readback, but descriptor construction, registration, reservation, explicit
sync timeline import, and release receipts are not public API.

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
