# Window Drawing

``Window`` exposes software drawing through ``SoftwareFrame`` and the current
``SurfaceGeometry``. WaylandClientKit owns the Wayland surface transaction, frame
callback bookkeeping, shared-memory pool selection, and presentation-feedback
requests.

Application code draws into the frame payload and asks the window to present it.
Each software frame reports an opaque ``SoftwareFrameBufferID`` for the borrowed
SHM buffer. ``SoftwareFrame/withBuffer(_:)`` provides scoped access to XRGB8888
bytes, stride, and geometry. The byte span is valid only inside the closure.
Use
``Window/show(damage:timeoutMilliseconds:requestPresentationFeedback:preparing:_:)``
and ``Window/redraw(damage:requestPresentationFeedback:preparing:_:)`` when
expensive scene preparation should
begin after WaylandClientKit has selected the authoritative software frame
geometry and reusable buffer identity. The preparation closure receives a
``SoftwareFrameReservation`` with buffer dimensions, stride, geometry, and
opaque identity. Mutable bytes remain scoped to the final draw closure. These
operations are latest-wins transactions: after preparation resumes,
WaylandClientKit revalidates the exact reservation, window, configure,
authoritative geometry, redraw generation, and task cancellation before it
borrows mutable bytes.

When asynchronous preparation is unnecessary, use
``Window/show(damage:requestPresentationFeedback:timeoutMilliseconds:_:)`` or
``Window/redraw(damage:requestPresentationFeedback:_:)`` to request feedback
atomically without a no-op preparation closure. These overloads return the same
``SoftwarePresentationOutcome``.

If the prepared generation is still current, WaylandClientKit draws, requests
the frame callback and optional presentation feedback, commits the surface, and
records the generation without another suspension point. If it is no longer
current, the library discards the reservation without invoking the draw closure
or issuing frame-callback, presentation-feedback, or surface-commit requests.
The newest dirty generation remains pending and produces one replacement redraw
request when pacing and buffer availability allow it.
GPU allocation experiments remain package-internal preview code.

## Asynchronous Preparation Outcomes

Asynchronous software presentation returns ``SoftwarePresentationOutcome``:

- `.presented` means the prepared frame was committed.
- `.superseded` means preparation finished after the reserved generation became
  stale, or the task was canceled after preparation without throwing. The
  prepared value is discarded and the newest redraw remains eligible.
- `.deferred` means no transaction began because redraw pacing or software-buffer
  availability did not permit one. The preparation closure is not invoked.
- `.closed` means the window or its display closed before the frame could be
  committed. The draw closure is not invoked.

Errors thrown by preparation or drawing remain errors. The reservation is
released and eligible redraw work is republished before the original operation
error is re-thrown.

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
