# Frame Leases

``WaylandGraphicsFrameLease`` is the move-only, single-use permission to submit
one frame through a ``WaylandGraphicsWindowBacking``.

## Lifecycle

Call ``WaylandGraphicsWindowBacking/nextFrame()`` to obtain a lease. Inspect
``WaylandGraphicsFrameLease/contract`` before rendering; it contains the current
surface generation, authoritative geometry, buffer candidates, synchronization,
and render-device identity. The `size`, `contract`, and `runtimePath` accessors
borrow their stored values, as do a render lease's `buffer` and `contract`.
Borrowed references cannot remain live across a consuming operation. An ordinary
local snapshot, such as `let contract = lease.contract`, is independently owned
and can outlive the lease or be passed to a task.

Submit the lease once with ``WaylandGraphicsFrameLease/submit(_:)``,
``WaylandGraphicsFrameLease/submitSoftware(metadata:_:)``, or by reserving a
registered external buffer with
``WaylandGraphicsFrameLease/reserveExternalBuffer(_:)`` and submitting the
returned render lease. Cancel the frame lease with
``WaylandGraphicsFrameLease/cancel()`` when no frame will be produced.

Submitting, cancelling, or reserving an external buffer consumes the lease, so
valid Swift source cannot copy the permission or use it twice. Reserving an
external buffer transfers the only remaining frame authority into the returned
move-only render lease. Submitting or cancelling that render lease consumes it;
render-lease cancellation cancels the entire frame permission.

A backing allows only one active lease. A consuming operation that throws
terminally releases its authority inside WCK because the caller no longer owns a
lease to cancel. Dropping an unfinished frame or render lease schedules the same
cleanup so it cannot strand `nextFrame()` or a buffer slot. Closing the backing
makes future lease operations fail with a typed error.

## Software, Clear, And External Frames

``WaylandGraphicsSubmittedFrame/clearColor(_:)`` submits a renderer-neutral clear
frame. On active managed GPU backing, the clear is rendered through internal GPU
preview code. On software backing or fallback, WaylandClientKit fills a
`SoftwareFrame`.

For external buffers, the renderer owns allocation and rendering; WCK owns
import, commit, release tracking, and reuse gating.

Registering an external descriptor transfers its plane descriptors to WCK.
Import and native buffer retirement run on the display's owner thread. Import
failure closes any untransferred descriptors. The renderer still owns the
underlying allocation.

Use `SurfaceFrameMetadata` and `SurfaceDamageRegion` to describe optional
surface metadata and logical damage. `nil` damage is the only full-frame
representation; a non-`nil` region contains at least one validated rectangle.
WaylandClientKit validates metadata and damage before irreversible commit work.
Validation failure still terminally releases the consumed frame authority.

WaylandClientKit owns lease state, new-frame retry behavior after pre-commit
failures, post-commit terminal state, and buffer reuse. Frameworks own frame
scheduling and failure policy. For continuous external rendering, call
`Window.requestRedraw()` and wait for that window's `DisplayEvent.redrawRequested`
before submitting the next frame.

A contract generation changes with surface geometry. Work for stale geometry
belongs to a new frame rather than the current lease.
