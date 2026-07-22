# Diagnostics And Display Failures

``DisplayDiagnostic`` reports recoverable degraded behavior and
feature-specific diagnostics.

``WaylandDisplayError`` covers fatal display or runtime failures and terminates
the affected stream.

Public control flow uses typed payloads and operations rather than message
strings.

WaylandClientKit owns publication and stream completion. Applications own
logging and recovery policy.

## Example

`WaylandClientKitDemo` in `Examples/WaylandClientKitDemo` prints basic input and
display state.
