# Software Fallback

Software fallback is an explicit runtime result, not a hidden success path.
When fallback is allowed, managed GPU setup can fail with a typed reason and the
same public frame submission can present through software.
If explicit synchronization has already been configured or activated on the
surface, implicit software fallback is not safe and the submission fails with a
typed unavailable reason instead.
When FIFO or commit-timing pacing is requested, software fallback applies the
same pacing submit constraint when the compositor supports it. Missing pacing
protocols are reported as typed runtime fallback facts instead of being silently
ignored.
FIFO pacing still uses barrier sequencing on software commits: the first
FIFO-paced software frame primes the barrier, and later FIFO-paced frames wait
and set the next barrier.

## Policies

- `WaylandGraphicsPresentationPolicy.managedGPU(fallback: .software)` attempts
  managed GPU clear-frame presentation and falls back with a typed
  ``WaylandGraphicsReason``.
- A managed or external GPU policy with `fallback: .unavailable` throws a typed
  unavailable/failure reason instead of falling back.
- `WaylandGraphicsPresentationPolicy.software` never attempts GPU presentation.

`WaylandGraphicsPresentationPolicy.externalGPU(fallback:)` is reserved for
renderer-owned external-buffer presentation. Normal clear/software submissions
do not become software submissions unless the external path has actually
entered its requested software fallback.

Use ``WaylandGraphicsFrameResult/backing`` and
``WaylandGraphicsRuntimePath/fallback`` to tell whether a submitted frame used
fallback.

## Reasons

``WaylandGraphicsReason`` describes both fallback and unavailable outcomes. It
can report missing dmabuf, missing surface feedback, no compatible
format, no render node, GBM/EGL setup failure, dmabuf import or compositor
commit failure, missing explicit sync, unsupported pacing, metadata or
presentation-feedback requirements, or forced software.

## Example

`GraphicsPreviewManagedGPUClear` requests managed GPU with fallback allowed and
prints the actual backing result.
