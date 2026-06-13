# Software Fallback

Software fallback is an explicit runtime result, not a hidden success path.
When fallback is allowed, managed GPU setup can fail with a typed reason and the
same public frame submission can present through software.
If explicit synchronization has already been configured or activated on the
surface, implicit software fallback is not safe and the submission fails with a
typed unavailable reason instead.

## Policies

- `WaylandGraphicsFallbackPolicy.preferGPUFallbackToSoftware` attempts managed
  GPU when requested and falls back to software with a typed
  ``WaylandGraphicsFallbackReason``.
- `WaylandGraphicsFallbackPolicy.requireGPU` attempts managed GPU and throws
  a typed unavailable/failure reason instead of falling back.
- `WaylandGraphicsFallbackPolicy.forceSoftware` never attempts managed GPU.

Use ``WaylandGraphicsFrameResult/backing`` and
``WaylandGraphicsRuntimePath/fallback`` to tell whether a submitted frame used
fallback.

## Reasons

Fallback can describe missing dmabuf, missing surface feedback, no compatible
format, no render node, GBM/EGL setup failure, dmabuf import or compositor
commit failure, missing explicit sync, unsupported pacing, metadata or
presentation-feedback requirements, or forced software.

## Example

`GraphicsPreviewManagedGPUClear` requests managed GPU with fallback allowed and
prints the actual backing result.
