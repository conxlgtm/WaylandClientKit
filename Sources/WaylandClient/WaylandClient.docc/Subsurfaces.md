# Subsurfaces

Subsurfaces are managed child surfaces attached to a parent ``Window``. They are useful for compositor-visible child planes that need an independent buffer lifecycle while remaining positioned and stacked relative to a parent.

Use ``Window/createSubsurface(configuration:)`` when a child needs its own content. Use ``Window/createPopup(configuration:)`` when xdg-shell transient placement and compositor dismissal semantics are required.

## Drawing

``Subsurface`` uses the same direct and prepared `show` and `redraw` contract as windows and popups. It accepts ``SurfaceFrameMetadata``, returns ``SoftwarePresentationOutcome``, exposes ``Subsurface/presentationEvents``, and publishes redraw work through ``DisplayEvent/redrawRequested(_:)`` with ``ManagedSurfaceIdentity/subsurface(_:)``.

Subsurfaces do not wait for an initial configure. Their prepared request captures the redraw generation, authoritative geometry, and synchronization mode. Scale changes, synchronization-mode changes, explicit redraws, cancellation, close, and parent close are revalidated before drawing.

## Synchronization

A synchronized child transaction commits in this order:

1. stage child metadata, damage, and attachment;
2. stage presentation success;
3. mark the child buffer busy;
4. request the child frame callback and optional presentation feedback;
5. commit the child surface; and
6. commit the parent surface.

The parent commit is part of the same nonthrowing point of no return. Rejected, deferred, superseded, canceled, metadata-invalid, and closed attempts commit neither child nor parent.

A desynchronized child commits only itself. Changing synchronization mode during asynchronous preparation supersedes the old request and keeps the newest generation dirty.

## Lifecycle And Redraw

``Subsurface/requestRedraw()`` publishes one root redraw event when work becomes eligible; it does not only set an internal flag. Parent-window close closes descendant subsurfaces, abandons reservations, terminates outstanding feedback, and releases frame callbacks and SHM resources.

## Capability Gate

Subsurfaces require `wl_subcompositor`. Stacking, position, and synchronization requests remain subject to parent/child lifetime and compositor rules. WaylandClientKit validates parent ownership, child lifecycle, stacking targets, and presentation state. Frameworks own layout and z-order policy.

## Example

See `ManagedSurfacePresentationSmoke` in `Examples/ManagedSurfacePresentationSmoke` for synchronized and desynchronized child presentation, redraw routing, feedback, and parent-close cleanup.
