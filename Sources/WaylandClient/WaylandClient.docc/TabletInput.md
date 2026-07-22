# Tablet Input

WaylandClientKit reports tablet protocol facts through ``InputEvent`` values.
Tablet events are seat-scoped and preserve device, tool, pad, serial, and
window-target facts where the compositor provides them.

``TabletEvent`` covers device arrival and removal, tool proximity and motion,
pressure, tilt, rotation, slider, wheel, buttons, and tablet-pad events. Unknown
protocol values use typed unknown cases.

Frameworks and apps should map tablet facts into their own editing or rendering
model.

Ring, strip, and dial events are not yet public. Current pad events cover
identity, path, buttons, enter and leave, group arrival, and removal.
