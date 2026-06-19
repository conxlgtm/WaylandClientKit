# Window Drawing

``Window`` exposes software drawing through ``SoftwareFrame`` and the current
``SurfaceGeometry``. WaylandClientKit owns the Wayland surface transaction, frame
callback bookkeeping, shared-memory pool selection, and presentation-feedback
requests.

Application code draws into the frame payload and asks the window to present it.
Each software frame reports an opaque ``SoftwareFrameBufferID`` for the borrowed
SHM buffer, so renderers can track which reusable buffer they are updating
without receiving raw Wayland or shared-memory handles. Use
``SoftwareFrame/withBuffer(_:)`` when renderer code needs scoped
``SoftwareFrameBuffer`` access to contiguous XRGB8888 bytes, stride, and
geometry. The byte span is valid only while the borrow closure is running.
Use ``Window/show(damage:timeoutMilliseconds:preparing:_:)`` and
``Window/redraw(damage:preparing:_:)`` when expensive scene preparation should
begin after WaylandClientKit has selected the authoritative software frame
geometry and reusable buffer identity. The preparation closure receives a
``SoftwareFrameReservation`` with buffer dimensions, stride, geometry, and
opaque buffer identity. The final draw closure still receives the only scoped
mutable byte access through ``SoftwareFrame``.
GPU allocation experiments remain package-internal preview code.

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
surface regions to the compositor. Input regions affect compositor targeting.
Frameworks remain responsible for hit testing. Opaque regions are compositor
optimization hints for fully opaque logical rectangles. Passing `nil` resets the
compositor default region.
