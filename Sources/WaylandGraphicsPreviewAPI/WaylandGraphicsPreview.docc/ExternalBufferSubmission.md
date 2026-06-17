# External Buffer Submission

External buffer submission is package-internal preview plumbing for
renderer-produced dmabuf frames. The public preview API does not expose this
descriptor boundary until a raw-handle-free renderer adapter is reviewed.

The renderer owns rendering and buffer production. WaylandClientKit owns the
Wayland import, surface commit, compositor release tracking, and late-release
cleanup for the submitted buffer.

## Descriptor Boundary

The internal descriptor boundary carries a positive pixel size, format and
modifier facts, and one to four plane values. The fd-consuming manufacturing
path remains package-internal.

Public APIs must not expose `wl_buffer`, `zwp_linux_buffer_params_v1`, GBM, EGL,
DRM nodes, syncobj handles, file descriptors, or raw pointers. Explicit public
fence or syncobj passing is deferred until a narrow ownership type is designed.

## Runtime Truth

Import failure, unsupported descriptors, missing dmabuf support, and unavailable
external synchronization produce typed errors or runtime fallback/failure facts.
Software fallback never reports that an external buffer was submitted.

Use `GraphicsPreviewExternalBufferSmoke -- --probe` for a bounded maintainer
capability report. That smoke target imports package-internal renderer helpers
only to manufacture live test buffers; it is not the public-user example for
renderer integration.
