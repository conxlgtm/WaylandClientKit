# External Buffer Submission

``WaylandGraphicsFrameLease/submitExternalBuffer(_:metadata:synchronization:schedule:)``
is a source-breaking preview API for renderer-produced dmabuf frames.

The renderer owns rendering and buffer production. WaylandClientKit owns the
Wayland import, surface commit, compositor release tracking, and late-release
cleanup for the submitted buffer.

## Descriptor Boundary

``WaylandGraphicsExternalBufferDescriptor`` carries a positive pixel size,
``WaylandGraphicsDRMFormat``, ``WaylandGraphicsDRMFormatModifier``, and one to
four ``WaylandGraphicsExternalBufferPlane`` values. Each plane owns an
`OwnedFileDescriptor` and transfers it into the import path exactly once.

The public API does not expose `wl_buffer`, `zwp_linux_buffer_params_v1`, GBM,
EGL, DRM nodes, syncobj handles, or raw pointers. External synchronization is
represented by ``WaylandGraphicsExternalSynchronization``; explicit public fence
or syncobj passing is intentionally deferred until a narrow ownership type is
designed.

## Runtime Truth

Import failure, unsupported descriptors, missing dmabuf support, and
unavailable external synchronization produce typed public errors or runtime
fallback/failure facts. Software fallback never reports that an external buffer
was submitted.

Use `GraphicsPreviewExternalBufferSmoke -- --probe` for a bounded capability
report, `--internal-test-buffer` for a bounded renderer-dmabuf import attempt,
and `--negative-test-buffer` for a pipe-descriptor cleanup failure probe.
