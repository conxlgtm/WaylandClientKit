# Diagnostics And Display Failures

``DisplayDiagnostic`` reports recoverable degraded behavior, dropped diagnostic
notices, input diagnostics, window diagnostics, data-transfer diagnostics, and
text-input diagnostics.

``WaylandDisplayError`` represents stream termination and fatal display/runtime
failures. Applications should treat diagnostics as observable state and display
errors as control-flow termination for the affected stream.

No public control flow requires parsing diagnostic message strings; use typed
diagnostic payloads and operations instead.

SwiftWayland's repository error taxonomy records which conditions use
feature-specific public errors, display errors, or diagnostics.
