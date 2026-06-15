# Output Topology

WaylandClientKit exposes output facts as public snapshots. It does not own
monitor settings policy.

Use ``WaylandDisplay/outputs()`` for the current output list and
``WaylandDisplay/outputTopology()`` when a stable, sorted output array is more
convenient. Output identities are stable within a display connection and are
reported as ``OutputID`` values. ``WindowStateSnapshot/outputs`` reports the
outputs currently associated with a managed window when the compositor sends
surface output membership.

When `zwlr_output_manager_v1` is advertised,
``WaylandDisplay/outputManagementSnapshot()`` exposes a preview list of output
heads using the wlroots output-management family. The preview is list-safe by
default. ``WaylandDisplay/testOutputConfiguration(_:)`` and
``WaylandDisplay/applyOutputConfiguration(_:)`` validate availability/staleness
but currently return a typed unsupported-operation error until the protocol's
manager serial and transaction lifecycle are modeled.

Snapshots can include scale, transform, physical size, make/model, current
mode, logical geometry, name, and description depending on what the compositor
advertises.

WaylandClientKit does not apply monitor configuration by default, choose display
modes, or decide placement policy. Frameworks can use these facts for layout,
restore hints, and renderer decisions above the substrate.

Use `OutputTopologySmoke` and `OutputManagementSmoke` for bounded
matrix-friendly reports.
