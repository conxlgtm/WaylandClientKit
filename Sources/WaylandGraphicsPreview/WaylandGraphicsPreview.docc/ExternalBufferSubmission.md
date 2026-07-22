# External Buffer Submission

Use external buffer submission when a renderer owns GPU images and wants WCK to
import and present those images through a window surface without staging normal
frames through shared-memory software buffers.

This source-breaking preview API consumes `OwnedFileDescriptor` ownership for
renderer-owned dma-buf images and DRM syncobj timelines. WCK owns import,
`wl_buffer` lifetime, commit, release tracking, and shutdown cleanup. It does not
expose raw protocol or renderer objects, pointers, or descriptor integers.

## Registered Public Flow

1. Create a backing with
   `WaylandGraphicsPresentationPolicy.externalGPU(fallback:)`, then await
   ``WaylandGraphicsWindowBacking/nextFrame()``.
2. Read ``WaylandGraphicsFrameLease/contract`` and choose a
   ``WaylandGraphicsExternalBufferConfiguration``. It includes format, modifier,
   alpha, scanout, synchronization, and renderer device identity.
3. Export each renderer-owned image as a
   ``WaylandGraphicsExternalBufferDescriptor`` with one to four
   ``WaylandGraphicsExternalBufferPlane`` values.
4. Register each descriptor with
   ``WaylandGraphicsWindowBacking/registerExternalBuffer(_:contract:configurationID:)``.
5. Reserve it with ``WaylandGraphicsFrameLease/reserveExternalBuffer(_:)``,
   render, and submit the returned lease. For DRM syncobj synchronization,
   import an acquire timeline with
   ``WaylandGraphicsWindowBacking/importExternalSyncTimeline(_:)`` and submit a
   `WaylandGraphicsExternalAcquireSynchronization.drmSyncobj(_:)` point.
6. Keep the allocation alive and unavailable while awaiting
   ``WaylandGraphicsExternalBufferSubmissionReceipt/waitForRelease()``. Reuse it
   only after `.released`.

Registration imports a descriptor once for reuse. It is scoped to the backing,
window, frame generation, and selected configuration. If that scope changes
during import, WCK removes the unpublished import and returns `backingClosed` or
`staleFrameContract`. Sync-timeline import follows the same rule.

## Release Authority

``WaylandGraphicsExternalBufferSubmissionReceipt`` is the ownership signal for a
submitted image. It identifies the submission, buffer, contract, frame result,
runtime report, release mechanism, and exactly-once terminal result:

- `WaylandGraphicsExternalReleaseSynchronization.implicitWaylandBufferRelease`
  uses the matching `wl_buffer.release` as its authority.
- `WaylandGraphicsExternalReleaseSynchronization.explicitSyncobjTimelinePoint`
  reports the compositor release timeline and point. `compositorAccepted` means
  the frame committed with explicit constraints, not that it was displayed or
  released.
- `.released` permits reuse. `.retired` means ownership tracking ended and the
  image should leave the pool. `.failed` is not proof of release. The allocation
  remains live until the backing has closed, then leaves the pool for disposal.

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

If DRM syncobj release polling fails, WCK marks the path failed, makes registered
slots unusable, and closes the backing and window before completing the failed
receipt. Other waiters retire with `.backingClosed`. Calling `close()` remains
safe and waits for cleanup already in progress.

Commits, frame callbacks, presentation feedback, timeouts, and later submissions
are not release evidence. Under explicit synchronization, neither is
`wl_buffer.release`. A buffer cannot be reserved while rendering, submitted, or
awaiting release. After release, it may be reserved again or unregistered.

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

``WaylandGraphicsWindowBacking/importExternalSyncTimeline(_:)`` consumes the DRM
syncobj descriptor on success and closes it on failure. The returned timeline is
backing-scoped. WCK retains its compositor mapping until the backing closes, so
renderers can import once and reuse later points.

Sync-file fences are not supported.

## Presentation Feedback Correlation

Release and presentation are independent terminal channels. Presentation
feedback never unlocks renderer buffer reuse; only
``WaylandGraphicsExternalBufferSubmissionReceipt/waitForRelease()`` does.

When requested, the receipt includes a
``WaylandGraphicsExternalPresentationFeedbackIdentity`` that pairs the
`SurfacePresentationIdentity` with its submission and buffer IDs.
``WaylandGraphicsExternalBufferSubmissionReceipt/waitForPresentationFeedback()``
completes once with `.presented`, `.discarded`, `.notRequested`, or `.retired`.

## Current Limitations

- No Vello, wgpu, Vulkan, EGL, or GLES object is public.
- Interop consumes dma-buf and syncobj descriptor ownership.
- Render-node information is device identity only. Applications map
  ``WaylandGraphicsRenderNode/deviceIDBytes`` through platform graphics APIs.
