# Event Streams And Overflow

``DisplayEvents``, ``InputEvents``, ``TextInputEvents``, ``DataTransferEvents``,
``WindowPresentationEvents``, and ``DisplayDiagnostics`` are independent public
streams.

Configure stream capacities with ``EventStreamConfiguration``. Subscriber
overflow is local to the affected stream subscription unless a diagnostic
represents a fatal input pipeline failure. ``TextInputEvents`` has an independent
text-input capacity. Display close and fatal display errors finish all streams.

Diagnostics are published both as display events and on the diagnostics stream.
Feature-specific diagnostics may also appear on their feature stream.

## Public APIs

- ``DisplayEvents``
- ``InputEvents``
- ``TextInputEvents``
- ``DataTransferEvents``
- ``WindowPresentationEvents``
- ``DisplayDiagnostics``
- ``EventStreamConfiguration``
- ``InputPipelineOverflow``

## Errors And Policy

SwiftWayland owns bounded stream buffering and typed overflow diagnostics.
Frameworks own subscriber lifetime, backpressure policy, and deciding whether to
drop, coalesce, or surface high-volume event traffic.
