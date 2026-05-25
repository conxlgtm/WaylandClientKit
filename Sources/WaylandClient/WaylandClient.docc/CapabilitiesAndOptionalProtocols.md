# Capabilities And Optional Protocols

``WaylandCapabilities`` is a registry-discovery snapshot. It reports whether the
compositor advertised optional protocols and which version SwiftWayland will use.

Registry advertisement is not always the same as runtime usability. For example,
linux-dmabuf may be advertised while a specific surface, device, or modifier set
is not usable for a particular GPU path. Surface-scoped and runtime-path facts
remain internal until their public shape is proven.

Applications should branch on ``ProtocolAvailability`` and handle unavailable
features with typed public errors. For example,
``WaylandCapabilities/xdgActivation`` can be available while a compositor still
declines a later activation request according to focus policy.
