# Output Topology

WaylandClientKit exposes output facts as public snapshots. It does not own
monitor settings policy.

Use ``WaylandDisplay/outputs()`` for the current output list and
``WaylandDisplay/outputTopology()`` when a stable, sorted output array is more
convenient. ``OutputID`` values are stable within a display connection.
``WindowStateSnapshot/outputs`` reports a managed window's output membership.

WaylandClientKit reports `zwlr_output_manager_v1` capability when advertised
and exposes preview output-management facts through
``WaylandDisplay/outputManagementSnapshot(timeoutMilliseconds:)``. The snapshot
is event-backed by manager head/mode events and has display-connection-scoped
head and mode identities.

Output-management mutation is not public.

Snapshots can include scale, transform, physical size, make/model, current
mode, logical geometry, name, and description depending on what the compositor
advertises.

WaylandClientKit reports monitor facts but does not choose modes, apply
configuration, or decide placement policy.

See `OutputTopologySmoke` and `OutputManagementSmoke` in `Examples/`.
