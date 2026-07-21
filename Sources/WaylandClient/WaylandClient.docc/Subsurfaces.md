# Subsurfaces

Subsurfaces are managed child surfaces attached to a parent ``Window``. They are
useful for compositor-visible child planes such as popovers, drag feedback, or
framework experiments that need separate surface lifetime without exposing raw
Wayland handles.

Use ``Window/createSubsurface(configuration:)`` when a child needs its own
surface content but remains positioned and stacked relative to a parent window.
Use a popup instead when xdg-shell transient positioning and dismissal semantics
are required.

## Capability Gate

Subsurfaces require `wl_subcompositor`. Stacking, position, and synchronization
mode requests are still subject to parent/child lifetime and compositor rules.

WaylandClientKit validates parent ownership, child lifecycle, stacking targets, and
presentation state. Frameworks own layout, z-order policy, and deciding whether
a feature should be a subsurface, popup, or content drawn into the parent
software frame.

## Example

See `SubsurfaceSmoke` in `Examples/SubsurfaceSmoke`.
