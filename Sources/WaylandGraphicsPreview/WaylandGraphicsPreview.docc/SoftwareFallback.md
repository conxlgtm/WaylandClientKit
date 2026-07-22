# Software Fallback

Software fallback is an explicit runtime result, not a hidden success path.
When fallback is allowed, managed GPU setup can fail with a typed reason and the
same public frame submission can present through software.
If explicit synchronization has already been configured or activated on the
surface, implicit software fallback is not safe and the submission fails with a
typed unavailable reason instead.
Software fallback keeps supported FIFO or commit-timing constraints. Missing
protocols produce runtime fallback facts. FIFO primes one commit, then waits and
sets the next barrier.

## Policies

- `WaylandGraphicsPresentationPolicy.managedGPU(fallback: .software)` attempts
  managed GPU clear-frame presentation and falls back with a typed
  ``WaylandGraphicsReason``.
- A managed or external GPU policy with `fallback: .unavailable` throws a typed
  unavailable/failure reason instead of falling back.
- `WaylandGraphicsPresentationPolicy.software` never attempts GPU presentation.

`externalGPU(fallback:)` is for renderer-owned buffers. Clear or software
submissions use software only after that path enters its requested fallback.

Use ``WaylandGraphicsFrameResult/backing`` and
``WaylandGraphicsRuntimePath/fallback`` to tell whether a submitted frame used
fallback.

## Reasons

``WaylandGraphicsReason`` covers missing capabilities, incompatible formats,
setup or commit failures, unsupported requirements, and forced software.

## Example

`GraphicsPreviewManagedGPUClear` requests managed GPU with fallback allowed and
prints the actual backing result.
