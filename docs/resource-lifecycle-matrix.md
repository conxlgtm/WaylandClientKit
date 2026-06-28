# Resource lifecycle matrix

WaylandClientKit handles are display-owned unless explicitly documented otherwise.
The public error type remains domain-specific, but the lookup vocabulary should
be consistent internally: found, unknown, closed, or foreign.

`unknown` means the ID is not active in the expected table. `closed` means the
owning display has closed. `foreign` means the handle belongs to another
display. Domain-specific states such as expired offers remain domain-specific
public errors.

## Matrix

| Resource | foreign display | unknown ID | closed display | closed window/surface | removed seat | destroyed resource | double destroy | late event after destroy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `Window` | typed foreign-window error | typed unknown-window error | `displayClosed` | close is terminal | n/a | close destroys role/surface | safe typed no-op or unknown | ignored if compositor-close duplicate |
| `PopupSurface` | typed foreign-popup error | typed unknown-popup error | `displayClosed` | parent close destroys popup subtree | n/a | close destroys popup role | safe typed no-op or unknown | ignored if popup already removed |
| `Subsurface` | typed foreign-subsurface error | typed unknown-subsurface error | `displayClosed` | parent close destroys child surface | n/a | close destroys subsurface role | close is idempotent or typed closed | pending frame callback is cancelled and ignored |
| `WindowIcon` / toplevel icon object | typed foreign-window error | typed unknown-window error | `displayClosed` | window close releases retained icon buffers | n/a | temporary icon object is immutable after assignment and destroyed after set | reset replaces previous icon state | late compositor use is avoided by keeping buffers alive until icon object destroy |
| `IdleInhibitor` | typed foreign-inhibitor error | `unknownIdleInhibitor` | `displayClosed` | window close destroys inhibitor | n/a | inhibitor destroyed | idempotent after known destroy | no callbacks expected |
| System bell request | typed foreign-window error for window-scoped request | typed unknown-window error | `displayClosed` | closed window rejects window-scoped request | n/a | one-shot request | n/a | no callbacks expected |
| `TextInputSession` | typed foreign-session error | typed unknown-session error | `displayClosed` | focused surface loss sends leave | `unknownSeat` or unavailable | disabled session is stale | deterministic typed error | ignored after disabled/remove-seat |
| `ClipboardOffer` | typed foreign-offer error | `unknownOfferIdentity` | `displayClosed` | n/a | offer expires if seat-owned path disappears | expired offer error | n/a | ignored after offer expiration |
| `PrimarySelectionOffer` | typed foreign-offer error | `unknownOfferIdentity` | `displayClosed` | n/a | offer expires if seat-owned path disappears | expired offer error | n/a | ignored after offer expiration |
| `DragOffer` | typed foreign-offer error | `unknownOfferIdentity` | `displayClosed` | drag target loss expires offer | seat removal expires drag path | expired offer error | n/a | ignored after drag leave/drop end |
| `ClipboardSource` | typed foreign-source error | typed unknown-source error | `displayClosed` | n/a | clear/cancel if seat path disappears | source cancelled | idempotent cancel or typed unknown | ignored after source cancellation |
| `PrimarySelectionSource` | typed foreign-source error | typed unknown-source error | `displayClosed` | n/a | clear/cancel if seat path disappears | source cancelled | idempotent cancel or typed unknown | ignored after source cancellation |
| `DragSource` | typed foreign-source error | typed unknown-source error | `displayClosed` | icon/window close cancels drag | seat removal cancels drag | source cancelled | idempotent cancel or typed unknown | ignored after drag source cancellation |
| `RelativePointerSubscription` | typed foreign-subscription error | `unknownRelativePointerSubscription` | `displayClosed` | n/a | subscription destroyed | subscription destroyed | typed unknown | ignored after proxy destroy |
| `PointerConstraint` | typed foreign-constraint error | `unknownPointerConstraint` | `displayClosed` | surface removal destroys constraint | seat removal destroys constraint | constraint destroyed | typed unknown | lifecycle event ignored after destroy |
| `ActivationToken` request | typed foreign-window error when bound to foreign window | unknown pending request is ignored | pending requests fail `displayClosed` | request cancellation if bound surface closes | request can complete without seat once submitted | pending request completes or cancels once | completion is single-shot | late done destroys request and does not revive waiter |
| `WaylandGraphicsWindowBacking` | typed foreign-backing error | typed unknown-backing error | `displayClosed` | backing closes with window | n/a | backing closed | close is idempotent or typed closed | ignored after backing close |
| `WaylandGraphicsFrameLease` | typed foreign-lease error | typed unknown-lease error | `displayClosed` | submit fails backing/window closed | n/a | lease closed/submitted | submit after close is typed closed | release callback ignored after lease close |
| `WaylandGraphicsExternalBuffer` | `externalBufferUnavailable(..., .foreign)` | `externalBufferUnavailable` with lifecycle state | registration/reservation fails closed | backing close retires registrations | n/a | unregister or backing close retires registration | duplicate reservation fails while busy, duplicate unregister is unavailable | late release after backing close is ignored |
| `WaylandGraphicsExternalBufferSubmissionReceipt` | n/a | n/a | release and presentation waiters resolve `backingClosed` | release and presentation waiters resolve `backingClosed` | n/a | receipt reaches one terminal release result and one terminal presentation result when requested | repeated waits return same result | late release or presentation feedback after backing close is ignored |
| `WaylandGraphicsExternalSyncTimeline` | typed unavailable when used across backing | typed unavailable when not imported | import fails closed | backing close removes imported acquire timeline mapping | n/a | WCK owns compositor mapping until backing close | duplicate point use is renderer policy, WCK validates imported identity | late release signal after backing close is ignored |
| Managed GPU buffer slot | n/a | missing slot is a presenter state error | `displayClosed` | backing retirement destroys imported buffer and releases locked GBM buffer | n/a | `wl_buffer.release` returns slot to available | duplicate release is ignored or recorded as presenter diagnostic | late release after backing close is ignored |

## Late callback policy

Late callbacks after resource destruction must be classified per domain:

- Expected protocol completions after cancellation are ignored once the public
  handle is stale.
- Recoverable unexpected callbacks should be surfaced through diagnostics rather
  than resurrecting public handles.
- Fatal errors are reserved for internal invariants, such as awaiting one
  one-shot activation request more than once.

## Helper usage

`DisplayResourceTable` is appropriate for simple display-owned ID-to-resource
stores. Do not force graph-shaped stores into it. `DisplaySurfaceStore` keeps
its dedicated topology model because surface roles, parentage, and popup
stacking are not a flat resource table.
