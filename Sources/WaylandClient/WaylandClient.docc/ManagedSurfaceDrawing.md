# Managed Surface Drawing

``Window``, ``PopupSurface``, and ``Subsurface`` expose one software drawing contract through ``SoftwareFrame``, ``SurfaceFrameMetadata``, and ``SoftwarePresentationOutcome``. WaylandClientKit owns shared-memory pool selection, buffer reservation, frame callbacks, metadata and damage staging, optional presentation feedback, commits, and cleanup.

Use each handle's simple `show` and `redraw` methods when scene preparation is synchronous. Use the prepared forms when expensive work should begin only after WaylandClientKit has selected the authoritative geometry and reusable buffer identity. The preparation closure receives a ``SoftwareFrameReservation``; mutable bytes remain scoped to the final draw closure.

```swift
let outcome = try await popup.show(
    metadata: .default,
    requestPresentationFeedback: true,
    preparing: { reservation in
        await renderer.prepare(for: reservation.geometry)
    },
    { prepared, frame in
        renderer.draw(prepared, into: frame)
    }
)
```

Windows and popups include the configure timeout on initial `show`. Subsurfaces are configure-independent and therefore do not.

## Latest-Wins Transactions

Prepared presentation reserves one exact redraw generation. After preparation resumes, WaylandClientKit revalidates:

- surface and parent lifecycle;
- reservation ownership and task cancellation;
- redraw generation;
- current popup placement or subsurface synchronization mode;
- authoritative geometry and scale; and
- metadata capability support.

Stale work returns `.superseded` before drawing or issuing callback, feedback, damage, attachment, or commit requests. The newest dirty generation remains eligible and produces one replacement `DisplayEvent.redrawRequested(ManagedSurfaceIdentity)` when pacing permits.

``SoftwarePresentationOutcome`` has four terminal states:

- `.presented`: the managed surface transaction committed;
- `.superseded`: preparation became stale or was canceled after returning;
- `.deferred`: pacing or buffer availability prevented a reservation, so preparation was not invoked; and
- `.closed`: the managed surface, its parent, or its display closed before commit.

Preparation and drawing errors release the reservation, preserve eligible redraw work, and rethrow the original caller error.

## Metadata And Damage

All three roles accept ``SurfaceFrameMetadata``. Unsupported explicit metadata is rejected before drawing, allocating a new pool, or issuing presentation-side requests. `metadata.damage == nil` is the only full-frame representation. A present-but-empty damage region means no damaged rectangles; it is not a full-frame sentinel.

Logical damage is validated before drawing, transformed using the final geometry and scale, clipped to the surface, and staged in the same commit transaction as attachment and metadata.

## Role-Specific Commit Boundaries

Window and popup commits retain their own configure and lifecycle reducers. The shared presentation engine owns only buffer and commit mechanics.

A desynchronized subsurface commits only its child surface. A synchronized subsurface commits the child and then its parent inside one irreversible boundary. `.presented` therefore means synchronized child state was latched through the parent, not merely cached for a later parent commit.

## Redraw Routing

Every role publishes redraw work through one root event:

```swift
case .redrawRequested(let surface):
    switch surface {
    case .window(let id):
        // redraw the window
    case .popup(let id):
        // redraw the popup
    case .subsurface(let id):
        // redraw the subsurface
    }
```

The complete ``DisplayEvents`` stream preserves ordering across redraw, presentation, lifecycle, input, data-transfer, output, and diagnostic events.

## Example

See `ManagedSurfacePresentationSmoke` in `Examples/ManagedSurfacePresentationSmoke` for window, popup, synchronized-subsurface, and desynchronized-subsurface presentation, redraw routing, optional feedback, popup cleanup, and parent-close cascade behavior. The default run exercises feedback and redraw routing. Use `--skip-feedback --skip-redraw-routing` for a bounded compositor-evidence run when the desktop does not deliver optional feedback or replacement frame callbacks promptly, and `--interactive-dismissal` to wait for a compositor popup dismissal.

See <doc:ManagedSurfacePresentationMigration> when updating code that used the
old window-only feedback events, popup redraw case, or subsurface `damage:`
overloads.
