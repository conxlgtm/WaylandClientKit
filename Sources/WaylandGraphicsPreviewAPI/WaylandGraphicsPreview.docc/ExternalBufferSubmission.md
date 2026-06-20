# External Buffer Submission

Use external buffer submission when a renderer owns GPU images and wants WCK to
import and present one image through the window surface without staging normal
frames through shared-memory software buffers.

This is source-breaking preview API. It is intentionally narrow: the first public
shape accepts one-plane renderer-owned dma-buf images, XRGB8888 or ARGB8888
format facts, a DRM modifier value, and one consumed `OwnedFileDescriptor`.
WCK still owns Wayland import, `wl_buffer` lifetime, surface commit, release
observation, and backing shutdown cleanup.

## Public flow

1. Create a ``WaylandGraphicsWindowBacking`` with a GPU-capable configuration.
2. Await ``WaylandGraphicsWindowBacking/nextFrame()``.
3. Read ``WaylandGraphicsFrameLease/contract`` before rendering.
4. Render into a compatible external GPU image owned by the caller.
5. Export a one-plane ``WaylandGraphicsExternalBufferDescriptor``.
6. Submit it with ``WaylandGraphicsFrameLease/submitExternalBuffer(_:metadata:schedule:)``.
7. Keep the renderer allocation alive until the returned
   ``WaylandGraphicsExternalBufferSubmissionReceipt`` reaches a terminal release
   result.

The descriptor is move-only. Passing it to WCK consumes the plane descriptor. If
validation or preflight fails, WCK closes descriptors it still owns before
returning the error.

## Release authority

``WaylandGraphicsExternalBufferSubmissionReceipt/waitForRelease()`` is the public
ownership signal for the submitted image.

- `WaylandGraphicsExternalReleaseResult.released` means WCK observed the
  authoritative implicit compositor buffer release for that submission.
- `WaylandGraphicsExternalReleaseResult.backingClosed` means the backing closed
  before normal release, so the caller should retire the image instead of reuse
  it for a later frame.
- `WaylandGraphicsExternalReleaseResult.failed` means WCK reached a
  terminal tracking failure for the submission.

A successful commit, frame callback, presentation feedback event, timeout, or
later frame submission is not release evidence.

## Synchronization scope

The public external-buffer path currently uses implicit synchronization. A
configuration that requires explicit synchronization fails before import with a
typed unavailable reason. The frame contract reports whether explicit sync is
advertised, but public external syncobj timeline import and release monitoring
are separate follow-up work.

## What stays private

Public external-buffer API does not expose raw Wayland objects, GBM/EGL objects,
DRM object handles, protocol proxies, raw pointers, or reusable borrowed file
descriptor access. The only public descriptor boundary is a move-only consuming
value backed by `OwnedFileDescriptor`.

## Current limitations

- External buffers are submitted per frame; persistent public registration is not
  available yet.
- The first public descriptor initializer is one-plane only.
- Explicit sync-file fences are not supported.
- DRM syncobj external-buffer submission is not public yet.
- WCK does not provide a Vello, wgpu, Vulkan, EGL, or GLES public object.
