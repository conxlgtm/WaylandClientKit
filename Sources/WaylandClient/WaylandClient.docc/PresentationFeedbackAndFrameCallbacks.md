# Presentation Feedback And Frame Callbacks

Frame callbacks and presentation feedback serve different purposes. Frame
callbacks tell WaylandClientKit when the compositor is ready for another surface
commit. Presentation feedback reports compositor timing facts for an already
submitted commit when the optional presentation-time protocol is available.

Use ``WindowPresentationEvents`` and ``PresentationFeedback`` for presentation
timing. Use window redraw requests to schedule drawing work.

Package-internal GPU preview commits can carry submit constraints and surface
metadata. Submit constraints govern latching or reuse; presentation feedback
reports what the compositor later observed.

`WaylandGraphicsPreview` reports related graphics-path facts without changing
ordinary `Window` redraw behavior.

## Capability Gate

Presentation feedback requires `wp_presentation`. Missing presentation-time
support is reported as unavailable. Frame callbacks are not treated as fake
presentation feedback.

WaylandClientKit owns requests, event correlation, and stream termination.
Frameworks own animation, frame budgeting, and fallback scheduling.

## Example

See `PresentationFeedbackAnimation` in `Examples/PresentationFeedbackAnimation`.
