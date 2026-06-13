# Window Drawing

``Window`` exposes software drawing through ``SoftwareFrame`` and the current
``SurfaceGeometry``. WaylandClientKit owns the Wayland surface transaction, frame
callback bookkeeping, shared-memory pool selection, and presentation-feedback
requests.

Application code draws into the frame payload and asks the window to present it.
The public API does not expose renderer, swapchain, scene graph, or widget
abstractions. GPU allocation experiments remain package-internal preview code.

``PopupSurface`` follows the same ownership rule as windows: it is a managed
surface, but popup placement and dismissal are governed by xdg-shell.

Use ``Window/show(damage:timeoutMilliseconds:_:)`` for the first frame and
``Window/redraw(damage:_:)`` for later partial redraws. Damage is expressed as
logical ``SurfaceDamageRegion`` rectangles. WaylandClientKit validates any damage
passed to `show`, but the first buffer-backed surface commit is sent as
full-frame damage because there are no previous buffer contents to preserve.
After that first buffer commit, WaylandClientKit maps logical damage to buffer
coordinates for the active scale and clips partial overhang to the surface
bounds. Passing no damage uses full-frame damage.

Use ``Window/setInputRegion(_:)`` and ``Window/setOpaqueRegion(_:)`` to publish
surface regions to the compositor. Input regions affect compositor targeting;
they do not replace framework hit testing. Opaque regions are compositor
optimization hints for fully opaque logical rectangles. Passing `nil` resets the
compositor default region.
