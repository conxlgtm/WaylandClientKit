# Error Taxonomy

WaylandClientKit separates recoverable feature absence, invalid user input,
nonterminal runtime diagnostics, and fatal display failure.

## Public Error Rules

| Condition | Public shape | Fatal to display? |
| --- | --- | --- |
| Optional protocol is not advertised | Feature-specific public error, such as `TextInputError.unavailable` or `DataTransferError.unavailable` | No |
| Seat or public handle is unknown | Feature-specific public error when the feature owns the seat or handle lookup | No |
| Window belongs to another display | Feature-specific error when the feature can name the offending handle, otherwise `ClientError.window` | No |
| Display was closed | `ClientError.display(.closed)` or `WaylandDisplayError` from a stream iterator | Yes for the current display lifetime |
| Public request has invalid data | Feature-specific public error | No |
| Protocol/runtime invariant fails | `WaylandDisplayError` or `RuntimeError` routed through the owner-thread fatal path | Usually yes |
| Recoverable degraded behavior | `DisplayDiagnostic` and, where useful, feature-local diagnostic events | No |

## Feature Notes

- Clipboard, primary selection, drag-and-drop, text input, presentation feedback,
  and cursor-shape all report optional-protocol absence through typed public
  errors or `WaylandCapabilities`.
- Text-input invalid request ordering is reported as `TextInputError` and also
  as a text-input diagnostic event.
- Input, data-transfer, text-input, and window diagnostics are promoted into
  `DisplayDiagnostics` so applications can observe degraded behavior in one
  stream.
- Stream overflow is local to the overflowing subscriber or stream family unless
  the stream documents a fatal pipeline condition.

## Scope Rules

- Display-level capabilities describe connection-start registry advertisements and negotiated
  versions.
- Seat-level availability belongs to seat managers and feature errors.
- Surface-level facts belong in `SurfaceCapabilitySnapshot`.
- Runtime-path facts, such as dmabuf allocation/import viability, must not be
  inferred from registry advertisement alone.
- Submit constraints use `SurfaceSubmitConstraintError` internally to
  distinguish missing explicit sync points, illegal points without an attached
  buffer, unavailable FIFO/commit-timing objects, and commit-timestamp conflicts.
- Surface commit metadata uses `SurfaceCommitMetadataError` internally to
  distinguish unavailable metadata protocols from missing per-surface metadata
  objects or unknown color-description references.
- `WaylandGraphicsPreview` exposes preview fallback and unavailable reasons for
  renderer-facing capability decisions. Software fallback is nonfatal, a
  required-GPU decision reports unavailability without closing the display.
- External explicit-release tracking failure is terminal for its graphics
  backing, not for the display. It fails the external runtime path and closes the
  backing because WCK can no longer prove compositor release.
