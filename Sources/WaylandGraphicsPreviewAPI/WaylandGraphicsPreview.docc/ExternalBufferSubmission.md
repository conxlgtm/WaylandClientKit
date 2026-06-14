# External Buffer Submission

``WaylandGraphicsFrameLease/submitExternalBuffer(_:metadata:synchronization:schedule:)``
is a source-breaking preview API for renderer-produced dmabuf frames.

The renderer owns rendering and buffer production. WaylandClientKit owns the
Wayland import, surface commit, compositor release tracking, and late-release
cleanup for the submitted buffer.

## Descriptor Boundary

``WaylandGraphicsExternalBufferDescriptor`` carries a positive pixel size,
``WaylandGraphicsDRMFormat``, ``WaylandGraphicsDRMFormatModifier``, and one to
four ``WaylandGraphicsExternalBufferPlane`` values. The FD-bearing plane
construction is package-internal maintainer preview plumbing; public clients
should treat external descriptors as opaque preview values until
WaylandClientKit grows a raw-handle-free renderer handoff.

The public API does not expose `wl_buffer`, `zwp_linux_buffer_params_v1`, GBM,
EGL, DRM nodes, syncobj handles, file descriptors, or raw pointers. External
synchronization is represented by ``WaylandGraphicsExternalSynchronization``;
explicit public fence or syncobj passing is intentionally deferred until a
narrow ownership type is designed.

## Runtime Truth

Import failure, unsupported descriptors, missing dmabuf support, and
unavailable external synchronization produce typed public errors or runtime
fallback/failure facts. Software fallback never reports that an external buffer
was submitted.

Use `GraphicsPreviewExternalBufferSmoke -- --probe` for a bounded public
capability report. The public smoke imports only `WaylandClient` and
`WaylandGraphicsPreview`; `--internal-test-buffer` and `--negative-test-buffer`
redirect to the maintainer smoke. The
`GraphicsPreviewExternalBufferMaintainerSmoke` command with
`--internal-test-buffer` is maintainer evidence for a renderer-dmabuf import
run.
