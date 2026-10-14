# Development Checkpoint Checklist

Tags are development checkpoints, not API-stability promises. Public API,
documentation, support status, and compositor evidence must agree before a tag.

Review [Compatibility Policy](compatibility-policy.md) for public API changes and
[Compositor Matrix](compositor-matrix.md) for runtime claims.

## Current Checkpoint Migration

Swift 6.4.0 is now the minimum toolchain. Packages still use Swift 6 language
mode. On Nix, SwiftPM uses a compiler-specific SDK/toolset and the default Swift
Build backend. Swift-native tools use per-tool runtime paths and the selected
SourceKit library without a global libc override. See
[Linux Dependencies](linux-dependencies.md) and [Tooling](tooling.md).

Artifact checks support per-target test runners, coverage exports, and release
object lists. The ownership baseline distinguishes `borrow` and `mutate`
accessors from borrowing/consuming getters before public accessor migration.
Public rendering behavior is unchanged.

Documentation coverage counts product-authored abstracts. Swift 6.4 compiler
probes confirmed that compile-time symbol emission omits inherited Swift
comments included by standalone module extraction.

| `WaylandClient` baseline | Counted abstracts | Eligible symbols |
| --- | --- | --- |
| Swift 6.4 | 98 | 1,552 |
| Previous | 183 | 1,552 |

The previous count included 85 inherited standard-library abstracts.
Product documentation is unchanged.

This checkpoint contains source-breaking `WaylandClient` and
`WaylandGraphicsPreview` changes:

- Replace `EventStreamConfiguration.displayEventCapacity` and
  `PositiveInt.defaultDisplayEventCapacity` with `eventCapacity` and
  `defaultEventCapacity`. The capacity now controls the complete
  `WaylandDisplay.events` feed.
- Replace the fragmented `TextInputEvent.preedit`, `committed`,
  `deleteSurroundingText`, `action`, and `done` cases with one
  `TextInputEvent.transaction`. Read the seat, target, done serial, match state,
  and optional compositor changes from `TextInputTransaction`.
  `TextInputPreeditEvent` becomes the nested `TextInputPreedit`,
  `TextInputDeleteSurroundingTextEvent` becomes `TextInputDeletion`, committed
  text moves directly onto the transaction, and `TextInputDoneEvent` is replaced
  by the transaction serial. Nested preedit, deletion, and action payloads no
  longer repeat the seat ID.
- Account for the serial results from `TextInputSession.commit()` and
  `TextInputSession.disable()`. Disable now sends its own commit and returns
  `nil` only when the session is already inactive or disabled.
- Update exhaustive `DisplayEvent` switches for the new `textInput`,
  `dataTransfer`, and `presentation` cases. `WaylandDisplay.events` is now the
  complete cross-family ordered feed; specialized streams remain
  family-ordered convenience views.
- Replace the former `Window.show` and `Window.redraw` overload families with
  one simple and one prepared method each. All four return discardable
  `SoftwarePresentationOutcome`, accept `SurfaceFrameMetadata`, and expose the
  same atomic `requestPresentationFeedback` option. Move `damage:` arguments
  into `SurfaceFrameMetadata.damage`; remove explicit no-op-preparation and
  legacy `Void` wrappers. Prepared generations are revalidated before drawing.
- Apply the same direct/prepared contract to `PopupSurface` and `Subsurface`.
  Popup configure/redraw/lifecycle changes and subsurface scale, synchronization,
  cancellation, and parent-close changes now produce typed latest-wins outcomes.
  Remove the subsurface `damage:` overloads and pass damage through metadata.
- Replace `DisplayEvent.redrawRequested(WindowID)`, `popupRedrawRequested`, and
  `presentation(WindowPresentationEvent)` with role-qualified
  `redrawRequested(ManagedSurfaceIdentity)` and
  `presentation(ManagedSurfacePresentationEvent)`. Replace
  `WindowPresentationEvents` with `ManagedSurfacePresentationEvents`; all three
  managed handles expose a filtered presentation sequence.
- Replace `WaylandGraphicsFrameMetadata`, `WaylandGraphicsDamageRegion`,
  `WaylandGraphicsContentType`, `WaylandGraphicsPresentationHint`,
  `WaylandGraphicsAlphaModifier`, `WaylandGraphicsColorAlphaMode`, and
  `WaylandGraphicsColorRepresentation` with the corresponding shared
  `WaylandClient` surface types. Pass `SurfaceFrameMetadata` to software and
  external-buffer submissions and read it from frame results. Use `nil` damage
  for a full-frame commit; empty damage regions are no longer a second sentinel.
- `WaylandGraphicsFrameLease` and `WaylandGraphicsExternalBufferRenderLease` are
  now move-only. Submission and cancellation consume the lease, and reserving an
  external buffer consumes the frame lease and transfers sole authority to the
  returned render lease. Snapshot metadata before a consuming call, acquire a
  new frame after a throwing terminal operation, and remove handling for the
  deleted `WaylandGraphicsError.frameLeaseConsumed` case.

## Swift 6.4 Cutover Validation

The local x86_64 Nix validation used the default Swift Build backend:

- `nix develop --command env -u WAYLAND_DISPLAY swift run wck ci release --verbose`
  passed with isolated headless Weston. It covered strict and release builds,
  unit tests, public and invalid clients, examples, DocC/API gates, both release
  shim targets, and the headless live, integration, TSan, and ASan paths.
- `nix develop --command swift run wck test tsan --verbose` passed all ten
  per-target runners.
- Unit coverage exports all ten test bundles together. Request coverage keeps
  executed LLVM records from all five filters when SwiftPM replaces its managed
  coverage directory. A regression test using `llvm-profdata` checks profile
  reset and counter accumulation.
- DocC and API verification passed using a fresh scratch tree at
  `WAYLAND_CLIENT_KIT_SWIFTPM_SCRATCH=/tmp/wck-phase1-isolated-symbols`.
- Bootstrap and its SwiftPM command plugin passed. Swift 6.3.2 was rejected by
  the 6.4 manifest before product compilation.
- Linked executables used the matching Nix glibc loader. Foundation child
  processes ran with empty and custom environments. Both declared Nix
  architectures produced platform-specific SDK metadata. Runtime checks ran on
  x86_64 only; aarch64 execution was not tested.
- The desktop SHM smoke client received its frame callback. This check exercised
  SHM, not active managed GPU.

Desktop request tests under TSan returned `.superseded` presentation outcomes
and failed their existing `.presented` assertions. The isolated Weston TSan and
ASan request-path commands passed. Those results apply to Weston; they do not
establish compatibility with every compositor or foundation readiness.
See [Linux Dependencies](linux-dependencies.md) for the compiler and runtime
warnings from these runs.

## Required Gates

Run from a clean working tree:

```bash
swift run wck tools toolchain-smoke
swift run wck ci release
swift run wck examples build
swift run wck compositor evidence-summary
swift run wck api dump
```

`ci release` runs the release build and tests, generated-file and shim checks,
DocC verification, public API verification, and an available live or headless
Wayland path.

`compositor evidence-summary` reports incomplete cells in the compositor matrix.
It does not replace review of the recorded command output.

Use `swift run wck ci foundation-check` only for a foundation-candidate claim.
It rejects incomplete compositor cells, environment skips, and manual-interaction
gaps.

## Additional Runtime Checks

Run sanitizer jobs where the host supports them:

```bash
swift run wck test tsan
swift run wck test asan
swift run wck smoke headless -- wck test request-paths
swift run wck smoke headless -- wck test request-paths-tsan
swift run wck smoke headless -- wck test request-paths-asan
```

AddressSanitizer uses `detect_leaks=0`; leak checks are informational because
Swift and XCTest runtime allocations vary by host. ThreadSanitizer uses
`safety/tsan-suppressions.txt` for named Swift runtime and libdispatch reports.
Project race reports must remain unsuppressed.

Under a desktop Wayland session, run:

```bash
swift run wck smoke live
swift run wck smoke integration
swift run wck smoke gpu-preview
swift run GraphicsPreviewManagedGPUClear -- --auto-close --print-summary
swift run --package-path Examples WaylandClientKitDemo
```

Record the compositor name, version, advertised protocols, runtime path, and
results in [Compositor Matrix](compositor-matrix.md). Weston-only results do not
establish compatibility with Mutter, KWin, or wlroots compositors.

Graphics preview claims include the runtime-path block from `smoke gpu-preview`,
the managed-GPU example result when available, exact missing interfaces, and any
advertised-but-broken path. An active managed GPU result requires a successful
live compositor run.

See [Linux Live Wayland Testing](live-wayland-testing.md) for command behavior
and optional-protocol skips.

## Tag Sequence

1. Confirm the working tree is clean and Swift 6.4.0 or newer is active.
2. Run the required gates.
3. Run applicable sanitizer and live compositor checks.
4. Update `docs/compositor-matrix.md` with command output and environment facts.
5. Review `docs/public-api-audit.md` and the generated public API report.
6. Update README and DocC support statements for user-visible changes.
7. Confirm protocol generation produces no diff.
8. Tag the checkpoint.

A tag can wait until required commands pass and public API, generated-file, shim,
documentation, and compositor-evidence changes have been reviewed.
