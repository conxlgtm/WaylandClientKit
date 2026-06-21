# External Buffer Submission

Use external buffer submission when a renderer owns GPU images and wants WCK to
import and present those images through a window surface without staging normal
frames through shared-memory software buffers.

This is source-breaking preview API. It is intentionally narrow: the public
shape accepts renderer-owned dma-buf images with one to four planes, XRGB8888 or
ARGB8888 format facts, a DRM modifier value, and one consumed
`OwnedFileDescriptor` per plane. WCK owns Wayland import, `wl_buffer` lifetime,
surface commit, release observation, and backing shutdown cleanup.

## Registered Public Flow

1. Create a ``WaylandGraphicsWindowBacking`` with a GPU-capable configuration.
2. Await ``WaylandGraphicsWindowBacking/nextFrame()``.
3. Read ``WaylandGraphicsFrameLease/contract`` before allocating or rendering.
4. Pick one exact ``WaylandGraphicsExternalBufferConfiguration`` from the
   contract.
5. Export each renderer-owned image as a
   ``WaylandGraphicsExternalBufferDescriptor`` with one to four planes.
6. Register each descriptor with
   ``WaylandGraphicsWindowBacking/registerExternalBuffer(_:contract:configurationID:)``.
7. Reserve an available registered buffer with
   ``WaylandGraphicsFrameLease/reserveExternalBuffer(_:)``.
8. Render into the reserved image.
9. Submit with ``WaylandGraphicsExternalBufferRenderLease/submit(metadata:schedule:)``.
   For DRM syncobj explicit synchronization, first import the renderer's acquire
   timeline with ``WaylandGraphicsWindowBacking/importExternalSyncTimeline(_:)``
   and submit an acquire point with
   ``WaylandGraphicsExternalBufferRenderLease/submit(acquireSynchronization:metadata:schedule:)``.
10. Keep the renderer allocation alive and unavailable to the renderer pool until
    the returned ``WaylandGraphicsExternalBufferSubmissionReceipt`` reaches a
    terminal release result.
11. When the renderer pool retires an image, call
    ``WaylandGraphicsWindowBacking/unregisterExternalBuffer(_:)`` after the
    image is available and no submitted use is awaiting compositor release.

Registration imports a descriptor once. Repeated frame submissions reuse the
registered WCK-side buffer and do not re-import the same renderer image.

The descriptor is move-only. Passing it to WCK consumes the plane descriptor. If
validation or preflight fails before import, WCK closes descriptors it still owns
before returning the error.

## Release Authority

``WaylandGraphicsExternalBufferSubmissionReceipt/waitForRelease()`` is the public
ownership signal for the submitted image.

- `WaylandGraphicsExternalReleaseResult.released` means WCK observed the
  authoritative release mechanism for that submission. In implicit mode this is
  `wl_buffer.release`; in DRM syncobj explicit mode this is the compositor
  signaling WCK's per-buffer release timeline point.
- `WaylandGraphicsExternalReleaseResult.backingClosed` means the backing closed
  before normal release, so the caller should retire the image instead of reuse
  it for a later frame.
- `WaylandGraphicsExternalReleaseResult.failed` means WCK reached a terminal
  tracking failure for the submission.

A successful commit, frame callback, presentation feedback event, timeout,
`wl_buffer.release` while explicit synchronization is active, or later frame
submission is not release evidence. A registered buffer cannot be reserved again
until WCK observes release for its previous submitted use. After release, the
registered buffer may be reserved again or unregistered.

## Synchronization Scope

The public external-buffer path supports implicit synchronization and DRM
syncobj explicit synchronization.

- `implicitOnly` submits without syncobj constraints and uses `wl_buffer.release`
  as release authority.
- `preferExplicit` uses DRM syncobj when the compositor, render node, imported
  acquire timeline, and per-buffer release timeline are available. Otherwise it
  falls back to implicit synchronization before rendering and reports a runtime
  fallback reason.
- `requireExplicit` fails before renderer work can be submitted when WCK cannot
  configure the acquire/release timeline contract.

Sync-file fences are not supported.

## What Stays Private

Public external-buffer API does not expose raw Wayland objects, GBM/EGL objects,
DRM object handles, protocol proxies, raw pointers, or reusable borrowed file
descriptor access. The public descriptor boundary is narrow and move-only:
external buffer planes consume `OwnedFileDescriptor`, and external sync timeline
import consumes `OwnedFileDescriptor`.

## Current Limitations

- Public descriptor initializers cover one to four planes.
- Explicit sync-file fences are not supported.
- WCK does not provide a Vello, wgpu, Vulkan, EGL, or GLES public object.
