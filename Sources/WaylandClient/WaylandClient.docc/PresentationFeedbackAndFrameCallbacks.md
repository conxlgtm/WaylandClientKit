# Presentation Feedback And Frame Callbacks

Frame callbacks and presentation feedback serve different purposes. Frame callbacks tell WaylandClientKit when a managed surface may submit another paced frame. Presentation feedback reports compositor timing facts for an already committed frame when `wp_presentation` is available.

Pass `requestPresentationFeedback: true` to the direct or prepared `show` and `redraw` methods on ``Window``, ``PopupSurface``, or ``Subsurface``. Feedback is requested inside the accepted callback-feedback-commit transaction. Superseded, deferred, closed, canceled, and metadata-rejected attempts request neither feedback nor a frame callback and do not commit.

Every feedback result enters the root stream as `DisplayEvent.presentation(ManagedSurfacePresentationEvent)`:

```swift
case .presentation(let event):
    print(event.surface, event.feedback)
```

``ManagedSurfacePresentationEvent/surface`` identifies the window, popup, or subsurface independently of ``SurfacePresentationIdentity``, which identifies one feedback request. Each handle's ``ManagedSurfacePresentationEvents`` sequence filters the same event family by ``ManagedSurfaceIdentity``.

A synchronized subsurface requests feedback for the child surface commit. The following parent commit makes that child state visible but does not change feedback ownership.

## Ordering And Lifetime

``DisplayEvents`` preserves root publication order across redraw, presentation, lifecycle, input, data-transfer, output, and diagnostic events. A handle-specific presentation sequence preserves order only for its selected surface.

Uncommitted feedback objects are canceled on precommit failure. Surface close terminates outstanding feedback for that surface but does not finish display-owned event sequences. Display close terminates all outstanding feedback and finishes both root and filtered streams after already-published events are delivered.

## Capability Gate

Presentation feedback requires `wp_presentation`. Requesting it when unavailable throws before drawing or presentation-side requests. Frame callbacks are never synthesized as feedback.

WaylandClientKit owns request lifetime, correlation, and stream termination. Frameworks own animation, frame budgeting, and fallback scheduling.

## Examples

See `PresentationFeedbackAnimation` for window timing and `ManagedSurfacePresentationSmoke` for all managed surface roles.
