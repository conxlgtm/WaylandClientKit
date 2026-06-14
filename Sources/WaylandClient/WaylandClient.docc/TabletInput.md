# Tablet Input

WaylandClientKit reports tablet protocol facts through ``InputEvent`` values.
Tablet events are seat-scoped and preserve device, tool, pad, serial, and
window-target facts where the compositor provides them.

Use ``TabletEvent`` for low-level input routing from drawing tablets, stylus
tools, and tablet pads. The event model exposes protocol facts such as tablet
arrival/removal, tool proximity, tool motion, pressure, tilt, rotation, slider,
wheel, buttons, and tablet-pad enter/leave/button events. Unknown protocol
values are preserved with typed unknown cases instead of crashing.

Tablet input remains a substrate API. WaylandClientKit does not define brushes,
strokes, gesture recognition, canvases, eraser behavior, or application drawing
policy. Frameworks and apps should map tablet facts into their own editing or
rendering model.

Tablet pad group child controls are currently retained and destroyed in the raw
protocol layer, but public ring, strip, and dial events are deferred. Public pad
events currently expose pad identity, path, buttons, button presses, enter/leave,
group arrival, and removal.

