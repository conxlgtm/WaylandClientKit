# Window Drawing

``Window`` exposes software drawing through ``SoftwareFrame`` and the current
``SurfaceGeometry``. WaylandClientKit owns the Wayland surface transaction, frame
callback bookkeeping, shared-memory pool selection, and presentation-feedback
requests.

Application code draws into the frame payload and asks the window to present it.
Each software frame reports an opaque ``SoftwareFrameBufferID`` for the borrowed
SHM buffer. ``SoftwareFrame/withBuffer(_:)`` provides scoped access to XRGB8888
bytes, stride, and geometry. The byte span is valid only inside the closure.
Use ``Window/show(damage:timeoutMilliseconds:preparing:_:)`` and
``Window/redraw(damage:preparing:_:)`` when expensive scene preparation should
begin after WaylandClientKit has selected the authoritative software frame
geometry and reusable buffer identity. The preparation closure receives a
``SoftwareFrameReservation`` with buffer dimensions, stride, geometry, and
opaque identity. Mutable bytes remain scoped to the final draw closure.
GPU allocation experiments remain package-internal preview code.

``PopupSurface`` follows the same ownership rule as windows: it is a managed
surface, but popup placement and dismissal are governed by xdg-shell.

Use ``Window/show(damage:timeoutMilliseconds:_:)`` for the first frame and
``Window/redraw(damage:_:)`` for later partial redraws. Damage is expressed as
logical ``SurfaceDamageRegion`` rectangles. WaylandClientKit validates any damage
passed to `show`; the first buffer commit uses full-frame damage. Later commits
map logical damage to scaled buffer coordinates and clip it to the surface.
Passing no damage uses the full frame.

Use ``Window/setInputRegion(_:)`` and ``Window/setOpaqueRegion(_:)`` to publish
surface regions to the compositor. Input regions affect compositor targeting.
Frameworks remain responsible for hit testing. Opaque regions are compositor
optimization hints for fully opaque logical rectangles. Passing `nil` resets the
compositor default region.
