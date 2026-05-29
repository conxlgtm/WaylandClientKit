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

Parent windows close their managed subsurfaces before their own role surface is
destroyed. Closing a subsurface does not close its parent window. Closed handles
are reported through typed display errors instead of silently reviving stale
state.

`SubsurfaceSmoke` creates a parent window, draws a child subsurface, moves it, and
prints the managed identity and motion log. Compositor behavior may vary, but the
example is meant to exercise object lifetime, child commits, and position
updates.
