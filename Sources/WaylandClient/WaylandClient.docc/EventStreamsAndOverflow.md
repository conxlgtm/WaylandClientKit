# Event Streams And Overflow

``DisplayEvents`` is the complete display event feed. It includes display and
window lifecycle, input, text input, data transfer, presentation, and diagnostic
events in owner-thread publication order.

``InputEvents``, ``TextInputEvents``, ``DataTransferEvents``,
``WindowPresentationEvents``, and ``DisplayDiagnostics`` remain available as
specialized convenience streams. ``DisplayEvents`` is the only stream that
preserves ordering across event families. A specialized stream preserves order
only within its own family.

Each call to `makeAsyncIterator()` creates its own subscription and buffer.
Buffering starts when the iterator is created, so events published before that
point are not replayed. Copying a sequence is safe: iterators made from either
copy receive events independently, and cancelling one iterator does not cancel
another.

Configure stream capacities with ``EventStreamConfiguration``.
``EventStreamConfiguration/eventCapacity`` controls the complete display
feed; each specialized stream has its own capacity. Subscriber overflow is local
to the affected stream subscription unless a diagnostic is a fatal input
pipeline failure. Display close and fatal display errors finish all streams
after delivering already-published events.

Diagnostics are published both as display events and on the diagnostics stream.
Feature-specific diagnostics may also appear on their feature stream.

WaylandClientKit owns bounded stream buffering and typed overflow diagnostics.
Frameworks own subscriber lifetime and backpressure policy.
