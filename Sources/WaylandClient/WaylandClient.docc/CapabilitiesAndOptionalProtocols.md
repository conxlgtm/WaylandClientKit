# Capabilities And Optional Protocols

``WaylandCapabilities`` is a connection-start usability snapshot. It reports
optional protocols found during initial discovery and the versions
WaylandClientKit bound or can bind. Reconnect to discover managers advertised
later. Removed managers become unavailable.

Registry advertisement is not always the same as runtime usability. For example,
linux-dmabuf may be advertised while a specific surface, device, or modifier set
is not usable for a particular GPU path. Surface-scoped and runtime-path facts
remain internal until their public shape is proven.

Use ``ProtocolAvailability`` to select features, and still handle typed request
errors. A compositor may advertise a protocol but decline a request.

``WaylandCapabilities/relativePointer`` and
``WaylandCapabilities/pointerConstraints`` report pointer capture protocols.
``WaylandCapabilities/pointerWarp`` reports the staging pointer-warp request
protocol. These input features are optional.

``WaylandCapabilities/compositorSessionManagement`` reports staging
`xdg_session_manager_v1` advertisement. It does not expose a session handle.
Scene, document, and local restore policy remain framework owned.
