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
