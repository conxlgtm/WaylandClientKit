# Frame Leases

``WaylandGraphicsFrameLease`` is the single-use permission to submit one frame
through a ``WaylandGraphicsWindowBacking``.

## Lifecycle

Call ``WaylandGraphicsWindowBacking/nextFrame()`` to obtain a lease. Inspect
``WaylandGraphicsFrameLease/contract`` before rendering; it contains the current
surface generation, authoritative geometry, external-buffer candidate facts, and
synchronization availability for the frame.

Submit the lease once with ``WaylandGraphicsFrameLease/submit(_:)``,
``WaylandGraphicsFrameLease/submitSoftware(metadata:_:)``, or
``WaylandGraphicsFrameLease/submitExternalBuffer(_:metadata:schedule:)``. Cancel
it with ``WaylandGraphicsFrameLease/cancel()`` when no frame will be produced.

A backing allows only one active lease. A submitted or cancelled lease cannot be
submitted again. Closing the backing makes future lease operations fail with a
typed error.

## Software, Clear, And External Frames

``WaylandGraphicsSubmittedFrame/clearColor(_:)`` submits a renderer-neutral clear
frame. On active managed GPU backing, the clear is rendered through internal GPU
preview code. On software backing or fallback, WaylandClientKit fills a
`SoftwareFrame`.

For reusable renderer-owned images, first register each descriptor with
``WaylandGraphicsWindowBacking/registerExternalBuffer(_:contract:configurationID:)``.
Then call ``WaylandGraphicsFrameLease/reserveExternalBuffer(_:)`` to create a
``WaylandGraphicsExternalBufferRenderLease``. Submit that render lease after the
renderer has finished drawing into the reserved image.

``WaylandGraphicsFrameLease/submitExternalBuffer(_:metadata:schedule:)`` remains
available as a direct descriptor submission path. Registered buffers are the
preferred ownership model for renderer pools because WCK can prevent reuse while
the previous submission is still awaiting compositor release.

External submission returns a ``WaylandGraphicsExternalBufferSubmissionReceipt``.
Keep the renderer-owned image alive until
``WaylandGraphicsExternalBufferSubmissionReceipt/waitForRelease()`` returns a
terminal result. Reusing an external image before that release result violates
the presentation ownership contract.

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
