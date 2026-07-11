# External Buffer Submission

Use external buffer submission when a renderer owns GPU images and wants WCK to
import and present those images through a window surface without staging normal
frames through shared-memory software buffers.

This is source-breaking preview API. The public boundary is intentionally narrow:
move-only descriptor values consume `OwnedFileDescriptor` ownership for
renderer-owned dma-buf images and DRM syncobj timelines. WCK owns Wayland import,
`wl_buffer` lifetime, surface commit, release observation, release waiters, and
backing shutdown cleanup. The public API does not expose raw Wayland proxies,
GBM/EGL objects, borrowed descriptor integers, raw pointers, or reusable file
descriptor access.

## Registered Public Flow

1. Create a ``WaylandGraphicsWindowBacking`` with
   `WaylandGraphicsPresentationPolicy.externalGPU(fallback:)`.
2. Await ``WaylandGraphicsWindowBacking/nextFrame()``.
3. Read ``WaylandGraphicsFrameLease/contract`` before allocating or rendering.
4. Pick one exact ``WaylandGraphicsExternalBufferConfiguration`` from the
   contract. The configuration includes the selected DRM format, modifier,
   alpha interpretation, scanout preference, synchronization availability, and
   ``WaylandGraphicsRenderNode/deviceIDBytes`` for renderer-side device
   selection.
5. Export each renderer-owned image as a
   ``WaylandGraphicsExternalBufferDescriptor`` with one to four
   ``WaylandGraphicsExternalBufferPlane`` values.
6. Register each descriptor with
   ``WaylandGraphicsWindowBacking/registerExternalBuffer(_:contract:configurationID:)``.
7. Reserve an available registered buffer with
   ``WaylandGraphicsFrameLease/reserveExternalBuffer(_:)``.
8. Render into the reserved image.
9. Submit the ``WaylandGraphicsExternalBufferRenderLease``. For DRM syncobj
   explicit synchronization, import an acquire timeline with
   ``WaylandGraphicsWindowBacking/importExternalSyncTimeline(_:)`` and submit a
   `WaylandGraphicsExternalAcquireSynchronization.drmSyncobj(_:)` point.
10. Keep the renderer allocation alive and unavailable to the renderer pool while
    awaiting ``WaylandGraphicsExternalBufferSubmissionReceipt/waitForRelease()``.
11. Reuse the image only after `.released`. A `.failed` result is terminal for
    the waiter but is not release evidence; close and await the backing before
    destroying that allocation. Retire an available image with
    ``WaylandGraphicsWindowBacking/unregisterExternalBuffer(_:)`` when the pool
    drops the allocation.

Registration imports a descriptor once. Repeated frame submissions reuse the
registered WCK-side buffer and do not re-import the same renderer image.
Registration is an atomic transaction scoped to the backing, window, frame
generation, and selected external configuration. If any of those facts changes
while the dma-buf import is suspended, WCK destroys the unpublished imported
buffer and returns `backingClosed` or `staleFrameContract` instead of publishing
a handle. Sync-timeline import follows the same rule and removes an unpublished
compositor timeline mapping when its transaction becomes stale.

## Release Authority

``WaylandGraphicsExternalBufferSubmissionReceipt`` is the ownership signal for a
submitted image. The receipt exposes the submission identity, buffer identity,
contract generation, frame result, runtime report, release mechanism, and an
exactly-once terminal release result. It also exposes typed release
synchronization facts:

- `WaylandGraphicsExternalReleaseSynchronization.implicitWaylandBufferRelease`
  means this receipt uses the matching `wl_buffer.release` as the release
  authority.
- `WaylandGraphicsExternalReleaseSynchronization.explicitSyncobjTimelinePoint`
  reports the WCK-owned release timeline ID and release point submitted to the
  compositor for this receipt. `compositorAccepted` only means WCK committed the
  frame with explicit sync constraints and did not fall back to implicit
  synchronization for this receipt. It does not mean displayed, presented, or
  released.

- `WaylandGraphicsExternalReleaseResult.released` means WCK observed the
  authoritative release mechanism for that submission. In implicit mode this is
  the matching `wl_buffer.release`; in DRM syncobj explicit mode this is the
  compositor signaling WCK's per-buffer release timeline point.
- `WaylandGraphicsExternalReleaseResult.retired(_:)` means the backing,
  window, or display ended ownership tracking before normal release. The caller
  should retire the image instead of reuse it for a later frame.
- `WaylandGraphicsExternalReleaseResult.failed(_:)` means WCK reached a
  terminal tracking failure for the submission. It does not prove that the
  compositor stopped using the image. Keep the allocation alive, close and await
  the owning backing, then destroy the allocation instead of returning it to the
  renderer pool.

Use the terminal result as an explicit allocation-lifetime branch:

```swift
switch await receipt.waitForRelease() {
case .released:
    rendererPool.recycle(allocation)
case .retired(_):
    rendererPool.retire(allocation)
case .failed(_):
    await backing.close()
    rendererPool.destroy(allocation)
}
```

If DRM syncobj release polling fails, WCK marks the external runtime path failed,
poisons every registered slot, and closes the backing and window before the
failed receipt completes. Other pending release and presentation waiters retire
with `.backingClosed`. Calling `close()` in the failure branch is still useful:
it is idempotent, joins cleanup already in progress, and states the renderer's
lifetime boundary directly.

A successful commit, frame callback, presentation feedback event, timeout,
`wl_buffer.release` while explicit synchronization is active, or later frame
submission is not release evidence. A late `wl_buffer.release` cannot revive a
slot after release tracking fails. A registered buffer cannot be reserved again
while it is rendering, submitted, or awaiting release. After release, the
registered buffer may be reserved again or unregistered.

## Synchronization Scope

The public external-buffer path supports implicit synchronization and DRM syncobj
explicit synchronization.

- `implicitOnly` submits without syncobj constraints and uses `wl_buffer.release`
  as release authority.
- `preferExplicit` uses DRM syncobj when the compositor, render node, imported
  acquire timeline, and per-buffer release timeline are available. Otherwise it
  falls back to implicit synchronization before rendering and reports a runtime
  fallback reason.
- `requireExplicit` fails before renderer work can be submitted when WCK cannot
  configure the acquire/release timeline contract.

``WaylandGraphicsWindowBacking/importExternalSyncTimeline(_:)`` consumes the
renderer-owned DRM syncobj timeline descriptor on success, or closes it on
failure. The returned timeline is scoped to the backing that imported it, and
timeline points are valid only when submitted back to the same backing. WCK keeps
the compositor timeline mapping alive until backing close; dropping the Swift
timeline value does not unregister the compositor mapping. Renderers may import
once per native source timeline and reuse later points without a per-frame
import.

Sync-file fences are not supported.

## Presentation Feedback Correlation

Release and presentation are independent terminal channels. Presentation
feedback never unlocks renderer buffer reuse; only
``WaylandGraphicsExternalBufferSubmissionReceipt/waitForRelease()`` does.

When presentation feedback is requested for an external-buffer frame, the
receipt includes a
``WaylandGraphicsExternalPresentationFeedbackIdentity`` that pairs the
`SurfacePresentationIdentity` with the same submission and buffer IDs as the
receipt. ``WaylandGraphicsExternalBufferSubmissionReceipt/waitForPresentationFeedback()``
then completes exactly once with `.presented`, `.discarded`, `.notRequested`, or
`.retired(_:)`. Presented and discarded results carry the same submission and
buffer IDs so diagnostics can distinguish submitted, displayed, discarded, and
retired frames.

## Current Limitations

- WCK does not provide a Vello, wgpu, Vulkan, EGL, or GLES public object.
- Public interop consumes ownership of dma-buf and syncobj file descriptors; it
  does not expose borrowed descriptor integers or protocol objects.
- Public render-node information is device identity only. Applications that need
  a native renderer object must use platform graphics APIs to map
  ``WaylandGraphicsRenderNode/deviceIDBytes`` to their own device or render node.
