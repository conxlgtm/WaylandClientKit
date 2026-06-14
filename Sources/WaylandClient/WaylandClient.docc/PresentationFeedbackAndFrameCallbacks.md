# Presentation Feedback And Frame Callbacks

Frame callbacks and presentation feedback serve different purposes. Frame
callbacks tell WaylandClientKit when the compositor is ready for another surface
commit. Presentation feedback reports compositor timing facts for an already
submitted commit when the optional presentation-time protocol is available.

Use ``WindowPresentationEvents`` and ``PresentationFeedback`` for presentation
timing. Use window redraw requests to schedule drawing work.

Package-internal GPU preview commits may also carry submit constraints and
surface commit metadata before the `wl_surface.commit` request. These facts are
separate from presentation feedback: submit constraints describe when a commit
may latch or when a buffer may be reused, while presentation feedback reports
what the compositor later observed. The public window redraw path continues to
use default metadata.

The `WaylandGraphicsPreview` product can project renderer-neutral graphics path
facts from public display capabilities, including presentation-feedback
advertisement and software fallback decisions. It does not change how frame
callbacks or presentation feedback are requested for ordinary `Window` redraws.

## Capability Gate

Presentation feedback requires `wp_presentation`. Missing presentation-time
support is reported as unavailable; frame callbacks are not treated as fake
presentation feedback.

## Public APIs

- ``Window/requestPresentationFeedback()``
- ``Window/presentationEvents``
- ``WindowPresentationEvents``
- ``PresentationFeedback``
- ``PresentationFeedbackFlags``

## Errors And Policy

WaylandClientKit owns the frame callback and presentation-feedback protocol
requests, event correlation, and stream termination. Frameworks own animation
timelines, frame budgeting, and whether a missing feedback protocol should fall
back to frame callbacks or wall-clock scheduling.

## Example

See `PresentationFeedbackAnimation` in `Examples/PresentationFeedbackAnimation`.
