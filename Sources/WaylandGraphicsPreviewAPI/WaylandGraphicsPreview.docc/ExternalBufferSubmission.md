# External Buffer Submission

External buffer submission is public preview plumbing for renderer-produced
dmabuf frames. The API is source-breaking preview and stays renderer-neutral:
callers provide a descriptor, not Wayland, GBM, EGL, DRM, syncobj, or raw
proxy objects.

The renderer owns rendering and buffer production. WaylandClientKit owns the
Wayland import, surface commit, compositor release tracking, and late-release
cleanup for the submitted buffer.

## Descriptor Boundary

The descriptor boundary carries a positive pixel size, DRM format and modifier
facts, and one to four plane values with owned file descriptors. Submitting a
descriptor transfers those file descriptors into WaylandClientKit's import
path.

Public APIs must not expose `wl_buffer`, `zwp_linux_buffer_params_v1`, GBM, EGL,
DRM nodes, syncobj handles, or raw pointers. Explicit public fence or syncobj
passing is deferred until a narrow ownership type is designed.

## Runtime Truth

Import failure, unsupported descriptors, missing dmabuf support, and unavailable
external synchronization produce typed errors or runtime fallback/failure facts.
Software fallback never reports that an external buffer was submitted.

Use `GraphicsPreviewExternalBufferSmoke -- --probe` for a bounded
capability report. The `--internal-test-buffer` mode is maintainer evidence for
a renderer-dmabuf import run; external clients compile against the descriptor
and lease API through the graphics preview integration client.

## Topics

### Descriptor Values

- ``WaylandGraphicsExternalBufferDescriptor``
- ``WaylandGraphicsExternalBufferPlane``
- ``WaylandGraphicsExternalBufferPlanes``
- ``WaylandGraphicsDRMFormat``
- ``WaylandGraphicsDRMFormatModifier``

### Submission

- ``WaylandGraphicsFrameLease/submitExternalBuffer(_:metadata:schedule:)``
