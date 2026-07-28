# Migrating To Managed Surface Presentation

The managed-surface presentation milestone replaces role-specific drawing and event contracts with one model for windows, popups, and subsurfaces.

## Redraw Events

Replace window-only and popup-specific cases:

```swift
case .redrawRequested(let windowID)
case .popupRedrawRequested(let lifecycle)
```

with one identity switch:

```swift
case .redrawRequested(.window(let windowID)):
    // redraw window
case .redrawRequested(.popup(let popupID)):
    // redraw popup
case .redrawRequested(.subsurface(let subsurfaceID)):
    // redraw subsurface
```

Popup lifecycle events continue to carry ``PopupLifecycleEvent`` through `popupDismissed` and `popupClosed`.

## Presentation Feedback

Replace `WindowPresentationEvent` and `WindowPresentationEvents` with ``ManagedSurfacePresentationEvent`` and ``ManagedSurfacePresentationEvents``. Root events now expose ``ManagedSurfacePresentationEvent/surface`` instead of `windowID`. Every `Window`, `PopupSurface`, and `Subsurface` exposes a filtered `presentationEvents` sequence.

Do not use ``SurfacePresentationIdentity`` as a stable surface key. It identifies one feedback request. Use ``ManagedSurfaceIdentity`` for the underlying managed role.

## Popup And Subsurface Drawing

Popup `show` and `redraw` now return ``SoftwarePresentationOutcome`` and accept ``SurfaceFrameMetadata`` plus optional feedback. Each also has a prepared overload.

Subsurface `show` and `redraw` use the same direct and prepared forms. Remove calls to the old `damage:` overloads and place damage in metadata:

```swift
let metadata = SurfaceFrameMetadata(damage: changedRegion)
let outcome = try await subsurface.redraw(metadata: metadata) { frame in
    draw(frame)
}
```

Handle `.superseded`, `.deferred`, and `.closed` when work is asynchronous or compositor state changes during preparation. Preparation is not invoked for `.deferred`, and the draw closure is not invoked for any rejected outcome.

## Synchronized Subsurfaces

A successful synchronized submission now includes the child commit followed by exactly one parent commit. `.presented` means the child state was latched through its parent. Callers no longer need to arrange a later parent commit for software presentation.
