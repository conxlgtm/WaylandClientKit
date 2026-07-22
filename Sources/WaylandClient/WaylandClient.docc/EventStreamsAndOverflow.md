# Event Streams And Overflow

``DisplayEvents``, ``InputEvents``, ``TextInputEvents``, ``DataTransferEvents``,
``WindowPresentationEvents``, and ``DisplayDiagnostics`` are independent public
streams.

Each call to `makeAsyncIterator()` creates its own subscription and buffer.
Buffering starts when the iterator is created, so events published before that
point are not replayed. Copying a sequence is safe: iterators made from either
copy receive events independently, and cancelling one iterator does not cancel
another.

Configure stream capacities with ``EventStreamConfiguration``. Subscriber
overflow is local to the affected stream subscription unless a diagnostic
is a fatal input pipeline failure. ``TextInputEvents`` has an independent
text-input capacity. Display close and fatal display errors finish all streams.

Diagnostics are published both as display events and on the diagnostics stream.
Feature-specific diagnostics may also appear on their feature stream.

WaylandClientKit owns bounded stream buffering and typed overflow diagnostics.
Frameworks own subscriber lifetime and backpressure policy.
