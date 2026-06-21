# External Buffer Submission

External buffer submission is currently package-scoped preview plumbing for
renderers that own GPU images and need WCK to import and present those images
through a window surface without staging normal frames through shared-memory
software buffers.

The shape is intentionally narrow: package-scoped descriptors accept
renderer-owned dma-buf images with one to four planes, XRGB8888 or ARGB8888
format facts, and a DRM modifier value. WCK owns Wayland import, `wl_buffer`
lifetime, surface commit, release observation, and backing shutdown cleanup.
The public API exposes renderer-neutral capability, configuration, and runtime
facts only; it does not expose descriptor construction, file descriptor transfer,
registration, external render leases, release receipts, or sync timeline import.

## Registered Package Flow

1. Create a ``WaylandGraphicsWindowBacking`` with a GPU-capable configuration.
2. Await ``WaylandGraphicsWindowBacking/nextFrame()``.
3. Read ``WaylandGraphicsFrameLease/contract`` before allocating or rendering.
4. Pick one exact ``WaylandGraphicsExternalBufferConfiguration`` from the
   contract.
5. Export each renderer-owned image as a package-scoped external buffer
   descriptor with one to four planes.
6. Register each descriptor with the package-scoped backing registration helper.
7. Reserve an available registered buffer with the package-scoped frame lease
   reservation helper.
8. Render into the reserved image.
9. Submit with the package-scoped external render lease.
   For DRM syncobj explicit synchronization, submit an acquire point with
   the package-scoped explicit synchronization submit helper.
10. Keep the renderer allocation alive and unavailable to the renderer pool until
    the returned package-scoped submission receipt reaches a terminal release
    result.
11. When the renderer pool retires an image, unregister it with the
    package-scoped backing helper after the image is available and no submitted
    use is awaiting compositor release.

Registration imports a descriptor once. Repeated frame submissions reuse the
registered WCK-side buffer and do not re-import the same renderer image.

The descriptor is move-only. Passing it to WCK consumes the plane descriptor. If
validation or preflight fails before import, WCK closes descriptors it still owns
before returning the error.

## Release Authority

The package-scoped submission receipt is the ownership signal for the submitted
image.

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

The package-scoped external-buffer path supports implicit synchronization and
DRM syncobj explicit synchronization.

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

The public graphics API does not expose raw Wayland objects, GBM/EGL objects,
DRM object handles, protocol proxies, raw pointers, file-descriptor handles,
syncobj handles, or reusable borrowed file descriptor access. External-buffer
descriptor construction and submission stay package-scoped until WCK has a
compliant public handle boundary.

## Current Limitations

- External-buffer descriptor construction and submission are package-scoped.
- Explicit sync-file fences are not supported.
- WCK does not provide a Vello, wgpu, Vulkan, EGL, or GLES public object.
