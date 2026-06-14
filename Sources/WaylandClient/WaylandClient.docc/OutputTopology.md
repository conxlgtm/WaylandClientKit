# Output Topology

WaylandClientKit exposes output facts as public snapshots. It does not own
monitor settings policy.

Use ``WaylandDisplay/outputs()`` for the current output list and
``WaylandDisplay/outputTopology()`` when a stable, sorted snapshot is more
convenient. Output identities are stable within a display connection and are
reported as ``OutputID`` values. ``WindowStateSnapshot/outputs`` reports the
outputs currently associated with a managed window when the compositor sends
surface output membership.

Snapshots can include scale, transform, physical size, make/model, current
mode, logical geometry, name, and description depending on what the compositor
advertises.

WaylandClientKit does not apply monitor configuration, choose display modes, or
decide placement policy. Frameworks can use these facts for layout, restore
hints, and renderer decisions above the substrate.

Use `OutputTopologySmoke` for a bounded matrix-friendly report.
