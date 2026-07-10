# Capabilities And Optional Protocols

``WaylandCapabilities`` is a registry-discovery snapshot. It reports whether the
compositor advertised optional protocols and which version WaylandClientKit will use.

Registry advertisement is not always the same as runtime usability. For example,
linux-dmabuf may be advertised while a specific surface, device, or modifier set
is not usable for a particular GPU path. Surface-scoped and runtime-path facts
remain internal until their public shape is proven.

Applications should branch on ``ProtocolAvailability`` and handle unavailable
features with typed public errors. For example,
``WaylandCapabilities/xdgActivation`` can be available while a compositor still
declines a later activation request according to focus policy.

``WaylandCapabilities/relativePointer`` and
``WaylandCapabilities/pointerConstraints`` report pointer capture protocols.
``WaylandCapabilities/pointerWarp`` reports the staging pointer-warp request
protocol. Applications should treat these as optional input features and keep a
fallback for compositors that do not support them or decline a later request.

``WaylandCapabilities/compositorSessionManagement`` reports staging
`xdg_session_manager_v1` advertisement. No public session handle is exposed
until the library can keep the protocol object alive, observe later replacement,
and attach restored or new surfaces. Scene, document, and local restore policy
remain framework owned.
