# Managed subsurface support

Subsurfaces are platform surface hierarchy, not widgets. SwiftWayland owns the
Wayland object lifetime, parent/child cleanup, surface scale installation, and
software frame commits. Frameworks still own layout, hit testing, z-order policy,
and dirty-region calculation.

The first managed API is intentionally conservative:

- `Window.createSubsurface(configuration:)` creates a child surface under a window.
- `Subsurface.show` and `Subsurface.redraw` use software frames and the shared
  surface commit path.
- `Subsurface.setInputRegion` and `Subsurface.setOpaqueRegion` use the same public
  `SurfaceRegion` model as windows and popups.
- `Subsurface.setPosition`, `placeAbove`, `placeBelow`, `setSynchronized`, and
  `setDesynchronized` expose protocol-level subsurface operations without adding
  framework layout policy.

Wayland applies subsurface creation, position, and stacking state through the
parent surface commit. SwiftWayland models that boundary explicitly: managed
creation, movement, stacking, synchronization-mode changes, and synchronized
child surface updates issue the required parent commit after the child-side
request or child commit. `setSynchronized` and `setDesynchronized` are effective
immediately and do not require a parent commit. `setDesynchronized` affects later
child content commits, but creation and position remain parent-applied protocol
state.

Self-stacking is rejected before any raw request because using a subsurface as
its own sibling is a Wayland protocol error. Cross-parent stacking also reports a
typed display error.

Parent windows close their managed subsurfaces before their own role surface is
destroyed. Closing a subsurface does not close its parent window. Closed handles
are reported through typed display errors instead of silently reviving stale
state.

`SubsurfaceSmoke` creates a parent window, draws a child subsurface, moves it, and
prints the managed identity and motion log. Each movement calls
`Subsurface.setPosition`, which sends the subsurface request and commits the
parent surface so compositor position state is applied. Compositor behavior may
vary, but the example is meant to exercise object lifetime, child commits, and
position updates.
