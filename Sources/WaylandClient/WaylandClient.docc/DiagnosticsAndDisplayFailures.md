# Diagnostics And Display Failures

``DisplayDiagnostic`` reports recoverable degraded behavior, dropped diagnostic
notices, input diagnostics, window diagnostics, data-transfer diagnostics, and
text-input diagnostics.

``WaylandDisplayError`` represents stream termination and fatal display/runtime
failures. Applications should treat diagnostics as observable state and display
errors as control-flow termination for the affected stream.

No public control flow requires parsing diagnostic message strings; use typed
diagnostic payloads and operations instead.

WaylandClientKit's repository error taxonomy records which conditions use
feature-specific public errors, display errors, or diagnostics.

## Public APIs

- ``DisplayDiagnostics``
- ``DisplayDiagnostic``
- ``DisplayDiagnosticPayload``
- ``WindowDiagnostic``
- ``InputDiagnostic``
- ``WaylandDisplay/diagnostics``

## Errors And Policy

WaylandClientKit owns diagnostic publication, typed payloads, and stream finishing.
Applications and frameworks own logging policy, user-facing recovery decisions,
and whether a diagnostic should be escalated into app-specific control flow.

## Example

`WaylandClientKitDemo` in `Examples/WaylandClientKitDemo` prints basic input and display
state. Smoke examples publish feature-specific diagnostics when optional
protocols are unavailable or rejected.
