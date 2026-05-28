# Window Drawing

``Window`` exposes software drawing through ``SoftwareFrame`` and the current
``SurfaceGeometry``. SwiftWayland owns the Wayland surface transaction, frame
callback bookkeeping, shared-memory pool selection, and presentation-feedback
requests.

Application code draws into the frame payload and asks the window to present it.
The public API does not expose renderer, swapchain, scene graph, or widget
abstractions. GPU allocation experiments remain package-internal preview code.

``PopupSurface`` follows the same ownership rule as windows: it is a managed
surface, but popup placement and dismissal are governed by xdg-shell.

Use ``Window/show(damage:timeoutMilliseconds:_:)`` for the first frame when a
dirty region is already known, and ``Window/redraw(damage:_:)`` for later
partial redraws. Damage is expressed as logical ``SurfaceDamageRegion``
rectangles. SwiftWayland maps logical damage to buffer coordinates for the
active scale and clips partial overhang to the surface bounds. Passing no damage
uses full-frame damage.

Use ``Window/setInputRegion(_:)`` and ``Window/setOpaqueRegion(_:)`` to publish
surface regions to the compositor. Input regions affect compositor targeting;
they do not replace framework hit testing. Opaque regions are compositor
optimization hints for fully opaque logical rectangles. Passing `nil` resets the
compositor default region.
