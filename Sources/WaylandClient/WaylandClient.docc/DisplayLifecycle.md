# Display Lifecycle

Use ``WaylandDisplay`` as the public connection object. A display owns the
underlying owner-thread session, public event streams, managed surfaces, cursor
state, data-transfer state, and text-input state.

Create public handles such as ``Window``, ``PopupSurface``, ``TextInputSession``,
``ClipboardOffer``, and ``DragSource`` from the display that owns them. Handles
from another display are rejected with public foreign-owner errors where the API
can detect that mismatch.

When a display closes normally, event streams finish. Fatal compositor or runtime
failures finish the streams with ``WaylandDisplayError``.
