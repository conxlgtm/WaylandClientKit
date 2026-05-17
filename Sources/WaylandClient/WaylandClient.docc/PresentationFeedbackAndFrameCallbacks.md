# Presentation Feedback And Frame Callbacks

Frame callbacks and presentation feedback serve different purposes. Frame
callbacks tell SwiftWayland when the compositor is ready for another surface
commit. Presentation feedback reports compositor timing facts for an already
submitted commit when the optional presentation-time protocol is available.

Use ``WindowPresentationEvents`` and ``PresentationFeedback`` for presentation
timing. Use window redraw requests to schedule drawing work.
