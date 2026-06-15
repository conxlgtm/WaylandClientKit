# External Buffer Submission

External buffer submission is package-internal maintainer preview plumbing for
renderer-produced dmabuf frames. It is not public `WaylandGraphicsPreview` API
yet because the compatibility policy requires the preview product to stay
renderer-neutral and raw-handle-free.

The renderer owns rendering and buffer production. WaylandClientKit owns the
Wayland import, surface commit, compositor release tracking, and late-release
cleanup for the submitted buffer.

## Descriptor Boundary

The current descriptor boundary carries a positive pixel size, DRM format and
modifier facts, and one to four plane values with owned file descriptors. That
is intentionally package-internal. Public APIs must not expose `wl_buffer`,
`zwp_linux_buffer_params_v1`, GBM, EGL, DRM nodes, dmabuf plane descriptors,
syncobj handles, file descriptors, or raw pointers.

Public renderer-produced buffer submission is deferred until there is an opaque
preview-buffer or renderer-neutral descriptor boundary. Explicit public fence or
syncobj passing is also deferred until a narrow ownership type is designed.

## Runtime Truth

Maintainer import failure, unsupported descriptors, missing dmabuf support, and
unavailable external synchronization produce typed errors or runtime
fallback/failure facts. Software fallback never reports that an external buffer
was submitted.

Use `GraphicsPreviewExternalBufferMaintainerSmoke -- --probe` for a bounded
capability report. The `--internal-test-buffer` mode is maintainer evidence for
a renderer-dmabuf import run, not a public integration sample.
