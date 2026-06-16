# Output Topology

WaylandClientKit exposes output facts as public snapshots. It does not own
monitor settings policy.

Use ``WaylandDisplay/outputs()`` for the current output list and
``WaylandDisplay/outputTopology()`` when a stable, sorted output array is more
convenient. Output identities are stable within a display connection and are
reported as ``OutputID`` values. ``WindowStateSnapshot/outputs`` reports the
outputs currently associated with a managed window when the compositor sends
surface output membership.

WaylandClientKit reports `zwlr_output_manager_v1` capability when advertised,
but public output-management control is deferred until manager head/mode events,
serials, and transaction lifecycle are modeled from that protocol.

Snapshots can include scale, transform, physical size, make/model, current
mode, logical geometry, name, and description depending on what the compositor
advertises.

WaylandClientKit does not apply monitor configuration by default, choose display
modes, or decide placement policy. Frameworks can use these facts for layout,
restore hints, and renderer decisions above the substrate.

Use `OutputTopologySmoke` for bounded matrix-friendly reports.
