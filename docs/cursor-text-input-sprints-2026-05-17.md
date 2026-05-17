# Cursor, Drag Visual, And Text-Input Sprints

Status: active near-term story  
Date: 2026-05-17  
Starting point: `main` after the foundation checkpoint PR series through PR #47

This document stores the next platform story after the foundation checkpoint.
The prior work left API contract checks, DocC scaffolding, compositor matrix
docs, public integration coverage, GPU preview checks, surface capability
snapshots, and the software presenter split in place.

The next work should stop being extension garden work. It should use the
surface runtime, capability, and presenter boundaries already in the codebase to
land feature substrate in two areas:

1. Cursor and drag visual surface foundation.
2. Text-input and IME substrate.

These are remaining user-visible platform gaps in `README.md`: drag icon
surfaces, cursor animation, output-scale cursor selection, cursor-shape support,
and text-input or IME behavior.

SwiftWayland should stay a Wayland platform substrate. These sprints must not
turn it into a renderer, scene graph, widget toolkit, text editor, or SwiftUI
clone.

## Sprint 1: Cursor And Drag Visual Surface Foundation

### Sprint Goal

Make cursor and drag-icon surfaces first-class surface-runtime clients instead
of isolated special cases. This sprint should keep static cursor behavior
compatible, prepare animated and mixed-DPI cursors, add compositor cursor-shape
support, and introduce drag icon surface substrate without adding a widget or
renderer layer.

### Why This Sprint

`SurfaceRuntime` already has roles for `.cursor` and `.dragIcon`, but the cursor
path still uses a dedicated `CursorManagerSurface` abstraction that directly
attaches a borrowed cursor buffer and commits the raw surface.

That means the project has the surface runtime abstraction ready, while cursor
surfaces are not yet using the same transaction and capability machinery as
windows, popups, and preview GPU paths. Drag icon support is also still listed
as unsupported, and public `DragIcon` is currently `.none` only.

### Story 1.1: Move Cursor Surfaces Onto `SurfaceRuntime`

Introduce an internal cursor role surface object:

```swift
package final class CursorRoleSurface {
    private let surface: RawSurface
    private var runtime = SurfaceRuntime<CursorRoleResources>(
        role: .cursor,
        surfaceID: surface.objectID
    )
}
```

Use it behind `CursorManagerSurface`, or replace `CursorManagerSurface` with a
more explicit protocol:

```swift
package protocol CursorSurfaceCommitting: AnyObject {
    var objectID: RawObjectID? { get }

    func commitStaticCursorImage(
        _ image: CursorImage,
        scaleContext: CursorScaleContext
    ) throws
    func destroy()
}
```

Move cursor attach, damage, and commit work out of
`LiveCursorManagerSurface.attach(_:)` and into a cursor surface presenter that
can later handle image scale, animation frames, and cursor-shape fallback.

Acceptance criteria:

- Existing static cursor behavior is unchanged.
- `CursorManager` still supports hidden cursors and named theme cursors.
- Cursor surface commits are tracked through cursor `SurfaceRuntime`.
- Cursor surface destruction goes through one explicit runtime path.
- Existing cursor tests pass.
- Tests cover cursor surface runtime destruction and repeated focus enter/leave.

Risk:

- Medium. Cursor behavior depends on pointer enter serials, and stale cursor
  commits must not happen after focus loss.

### Story 1.2: Add Cursor-Shape Protocol Support

Vendor and generate `cursor-shape-v1` protocol artifacts.

Add raw wrappers:

```text
RawCursorShapeManager
RawCursorShapeDevice
RawCursorShape
```

Add optional global binding and capability reporting:

```swift
public struct WaylandCapabilities {
    public let cursorShape: ProtocolAvailability
}
```

Add a mapping layer:

```swift
extension PointerCursor {
    package var cursorShapeName: RawCursorShapeName? { ... }
}
```

Cursor manager policy:

1. If cursor-shape is available and the requested cursor maps to a protocol
   shape, use compositor-managed cursor shape.
2. Otherwise, fall back to existing wayland-cursor theme surfaces.
3. Keep `.hidden` behavior as a nil surface request.

Acceptance criteria:

- `WaylandCapabilities` reports cursor-shape availability.
- Static theme cursor path still works when cursor-shape is absent.
- Missing theme diagnostics are not emitted when cursor-shape successfully
  handles the cursor.
- Unknown or unmappable `PointerCursor` names fall back to theme behavior.
- Live tests skip if `wp_cursor_shape_manager_v1` is absent and fail if it is
  advertised but broken.

Risk:

- Medium. Public mapping should be conservative. Do not map cursor names unless
  the protocol shape is clear.

### Story 1.3: Add Output-Scale Cursor Selection

Model cursor scale choice using the focused surface output context. The current
output membership model exists for windows and surface capability snapshots, but
cursor images still come from a fixed `CursorConfiguration.size`.

Introduce:

```swift
package struct CursorScaleContext: Equatable, Sendable {
    package let seatID: SeatID
    package let focusedSurfaceID: RawObjectID
    package let outputIDs: [OutputID]
    package let preferredScale: SurfaceScale
}

package enum CursorScalePolicy: Equatable, Sendable {
    case fixed(PointerCursorPixelSize)
    case matchFocusedSurface
    case maximumOutputScale
}
```

Keep the first policy internal until behavior is proven.

Acceptance criteria:

- Cursor image scale selection is deterministic.
- Moving pointer focus between outputs can trigger cursor replacement when scale
  changes.
- Unknown output membership falls back to configured size.
- Tests cover no outputs, one output, mixed-scale outputs, and focus loss.

Risk:

- Medium to high. Mixed-DPI behavior varies by compositor, so keep the first
  version internal and test the pure policy separately.

### Story 1.4: Add Cursor Animation Support

The current cursor code resolves one `CursorImage` and commits it. Add support
for cursor themes with multiple frames.

Introduce:

```swift
package struct AnimatedCursorFrame {
    package let image: CursorImage
    package let delay: Duration
}

package final class CursorAnimationState {
    package var currentFrameIndex: Int
    package var generation: UInt64
}
```

Owner-thread scheduling must stop on:

- pointer focus loss
- seat removal
- cursor replacement
- hidden cursor
- surface destruction
- output scale change
- display close

Acceptance criteria:

- Static cursor behavior remains unchanged.
- Animated cursor frames advance deterministically in unit tests.
- Stale scheduled ticks cannot commit after focus loss or cursor replacement.
- Cursor diagnostics report animation and theme problems without spamming input
  events.
- No arbitrary background work outside the Wayland owner thread.

Risk:

- High. The scheduler must be tied carefully to the owner-thread event loop.

### Story 1.5: Add Drag Icon Surface Substrate

Extend `DragIcon` beyond `.none` only when the surface lifetime model is ready.
Keep the API conservative:

```swift
public enum DragIcon: Equatable, Sendable {
    case none
    case software(DragIconConfiguration)
}

public struct DragIconConfiguration: Equatable, Sendable {
    public let size: PositiveLogicalSize
    public let hotspot: LogicalOffset
}
```

Because drawing closures are not `Equatable`, consider an internal-only
substrate first:

```swift
package final class DragIconRoleSurface
package struct PreparedDragIconSurface
```

The drag icon path should:

- create a `wl_surface`
- use `SurfaceRuntime(role: .dragIcon)`
- attach a SHM buffer
- commit before or during `start_drag`
- destroy on drag cancellation, finish, source destruction, display close, and
  failed start

Acceptance criteria:

- Existing `DragIcon.none` behavior is unchanged.
- Source-side drag can attach a managed icon surface internally.
- Drag source cancellation destroys the icon surface.
- Display close destroys any live drag icon surfaces.
- Tests cover every drag-source lifecycle exit.

Risk:

- Medium. Drag icon lifecycle crosses data-transfer, surface, and window-origin
  code.

### Story 1.6: Cursor And Drag Surface Docs And Tests

Update:

```text
README.md
docs/roadmap.md
docs/strict-memory-safety-audit.md
docs/live-wayland-testing.md
Sources/WaylandClient/WaylandClient.docc/WaylandClient.md
```

Add tests:

```text
CursorSurfaceRuntimeTests
CursorShapeCapabilityTests
CursorScalePolicyTests
CursorAnimationStateTests
DragIconSurfaceLifecycleTests
DataTransferManagerDragIconTests
```

Sprint 1 exit criteria:

- Cursor surfaces use the shared surface-runtime model internally.
- Cursor-shape support is capability-gated.
- Cursor scale policy exists and is tested.
- Cursor animation has an internal state model and deterministic tests.
- Drag icon surface substrate exists, at least internally.
- README unsupported list is updated if drag icons or cursor-shape become
  supported.
- No public renderer, scene graph, or widget abstractions are introduced.

## Sprint 2: Text-Input And IME Substrate

### Sprint Goal

Add real text-entry substrate through `text-input-v3`, while keeping it separate
from local keyboard interpretation. This is a major remaining foundation gap for
desktop applications.

### Why This Sprint

The roadmap distinguishes keyboard interpretation from real text input and lists
text-input/IME as a foundation gap. The README also says text-input and IME
protocols are not implemented.

Current keyboard support is xkbcommon-backed local interpretation of copied
`xkb_v1` keymaps. That is useful for shortcuts and simple key text, but it is
not compositor or IME text entry.

### Story 2.1: Generate And Classify Text-Input Protocol Artifacts

Vendor and generate:

```text
unstable/text-input/text-input-unstable-v3.xml
```

Add protocol tier metadata to docs:

```text
zwp_text_input_manager_v3
zwp_text_input_v3
```

Add C shims only for requests and listeners needed by the Swift raw wrapper.

Acceptance criteria:

- Generated artifacts verify cleanly.
- Shim verification passes.
- Roadmap protocol matrix has text-input phase, support, test, and breakage
  policy.
- No public API lands in this story.

Risk:

- Low to medium. Protocol generation itself should be straightforward.

### Story 2.2: Add Raw Text-Input Wrappers

In `WaylandRaw`, add wrappers:

```swift
package final class RawTextInputManager
package final class RawTextInput
package final class RawTextInputOwner
```

Raw events should preserve protocol facts:

```swift
package enum RawTextInputEvent: Equatable, Sendable {
    case enter(surfaceID: RawObjectID?)
    case leave(surfaceID: RawObjectID?)
    case preeditString(RawTextInputPreedit)
    case commitString(String)
    case deleteSurroundingText(beforeLength: UInt32, afterLength: UInt32)
    case done(serial: UInt32)
}
```

Requests:

```swift
func enable()
func disable()
func setSurroundingText(_ text: String, cursor: Int, anchor: Int)
func setTextChangeCause(_ cause: RawTextInputChangeCause)
func setContentType(hint: RawTextInputContentHint, purpose: RawTextInputContentPurpose)
func setCursorRectangle(x: Int32, y: Int32, width: Int32, height: Int32)
func commit()
```

Acceptance criteria:

- Raw wrapper lifetime follows `RawOwnedProxy`.
- Listener lifetime uses `CListenerStorage` and `ListenerInstallState`.
- Raw events preserve unknown enum values.
- Invalid UTF-8 or byte-index violations become typed errors or diagnostics.
- Unit tests cover listener callbacks, request mapping, and destroy idempotence.

Risk:

- Medium. Surrounding-text byte offsets and event ordering need careful tests.

### Story 2.3: Add Seat-Scoped Text-Input Manager In `WaylandClient`

Add a client-side manager:

```swift
package final class TextInputManager
```

Responsibilities:

- bind text-input manager when advertised
- create text input objects per seat
- track seat focus and enabled state
- map raw text-input events into public events
- expose typed unavailable errors

Public capability:

```swift
public struct WaylandCapabilities {
    public let textInput: ProtocolAvailability
}
```

Internal state:

```swift
package enum TextInputSeatState {
    case unavailable
    case inactive
    case enabled(surface: InputEventTarget)
    case focused(surface: InputEventTarget)
}
```

Acceptance criteria:

- Missing text-input support is reported through capabilities and typed errors.
- Seat removal destroys text-input state.
- Display close terminates text-input streams.
- Text-input events never appear as keyboard interpretation events.
- Unit tests cover seat removal, focus enter/leave, enable/disable, and display
  close.

Risk:

- Medium. Boundaries between input routing, surfaces, and text-input focus must
  stay explicit.

### Story 2.4: Shape Public Text-Input API Conservatively

Do not build a text-field widget. Expose protocol-shaped primitives.

Potential public API:

```swift
public struct TextInputSession: Sendable, Hashable {
    public let seatID: SeatID
    public func enable(for window: Window) async throws
    public func disable() async throws
    public func setSurroundingText(_ text: String, cursor: String.Index, anchor: String.Index) async throws
    public func setContentType(hints: TextInputContentHints, purpose: TextInputContentPurpose) async throws
    public func setCursorRectangle(_ rect: LogicalRect) async throws
    public func commit() async throws
}

public enum TextInputEvent: Equatable, Sendable {
    case entered(TextInputFocusEvent)
    case left(TextInputFocusEvent)
    case preedit(TextInputPreeditEvent)
    case committed(TextInputCommitEvent)
    case deleteSurroundingText(TextInputDeleteSurroundingTextEvent)
    case done(TextInputDoneEvent)
}
```

Add a display stream:

```swift
public nonisolated var textInputEvents: TextInputEvents
```

Alternatively, fold into `InputEventKind` only if text entry should remain under
`inputEvents`. A separate stream is preferred initially so keyboard and IME
output do not get confused.

Acceptance criteria:

- API does not expose raw `zwp_text_input_v3` handles.
- Public docs say this is compositor/IME text input, not keyboard shortcut text.
- Public events are machine-matchable.
- Public API audit is updated.
- Public API baseline is updated.

Risk:

- High. Public API naming matters. Keep it small and protocol-truthful.

### Story 2.5: Text-Input Event Ordering And Validation

Add a reducer/state machine for protocol ordering:

```swift
package struct TextInputState {
    mutating func reduce(_ event: RawTextInputEvent) throws -> [TextInputEffect]
}
```

Test:

- preedit before done
- commit string before done
- delete surrounding text before done
- multiple updates before done
- enter/leave invalidating state
- disable clearing pending state
- done publishing one coherent batch

Acceptance criteria:

- Public event order is deterministic.
- `done` is modeled as a transaction boundary.
- Invalid sequence produces diagnostics or typed errors, not silent corruption.
- Unknown values are preserved.

Risk:

- Medium to high. This is the core correctness story.

### Story 2.6: Live And Fixture Tests For Text Input

Live IME tests are hard because environments differ. Start with raw/unit tests
and a capability-gated live smoke:

```text
TextInputRawOwnerTests
TextInputStateTests
TextInputManagerTests
WaylandTextInputPublicIntegrationTests
```

Live test behavior:

- skip if `zwp_text_input_manager_v3` is absent
- if advertised, create a text input object and verify enable/disable request
  path
- do not require a real IME to commit text in CI unless the environment provides
  one

Acceptance criteria:

- Optional live test follows documented skip/fail rules.
- Unit tests cover real event ordering.
- Public integration confirms typed unavailable behavior.

Risk:

- Medium. Live IME coverage may remain limited until the compositor matrix is
  populated.

### Story 2.7: Text-Input DocC And Public Contract

Update:

```text
docs/public-api-audit.md
docs/roadmap.md
docs/live-wayland-testing.md
Sources/WaylandClient/WaylandClient.docc/WaylandClient.md
```

Also make DocC verification catch stale symbol references. The current verifier
checks that a catalog and symbol graph exist, but it does not prove that DocC
symbol links resolve.

Possible checks:

```bash
swift package generate-documentation \
  --target WaylandClient \
  --warnings-as-errors
```

or a lightweight symbol-link verifier that checks backticked DocC symbols
against the symbol graph.

Acceptance criteria:

- Text-input public API is documented.
- DocC links resolve or the check fails.
- Current stale DocC topic links are fixed.
- Public API audit includes text-input only after public API lands.

Risk:

- Low to medium. DocC tooling on Linux can be finicky; a symbol-link verifier
  may be easier than full DocC generation.

Sprint 2 exit criteria:

- Text-input protocol artifacts exist.
- Raw text-input wrappers and listeners are tested.
- Client-side text-input manager exists.
- Public API is either added conservatively or staged package-internally with
  clear naming.
- Keyboard interpretation and text-input remain separate concepts.
- Capability, errors, docs, public API baseline, and integration tests agree.

## Cross-Sprint Work

### DocC Link Verification

The DocC scaffold exists, but verification should catch unresolved topic
symbols. Replace stale symbols with current public names such as
`PopupSurface`, `SoftwareFrame`, and `SurfaceGeometry`, then add a verifier that
parses DocC symbol references and checks them against the public symbol graph.

### Protocol Support Manifest

The roadmap says every vendored/generated protocol should record upstream path,
phase, version, checksum, and SwiftWayland tier. Add:

```text
protocols/swiftwayland-protocol-manifest.json
```

Example entry:

```json
{
  "interface": "wp_presentation",
  "sourcePath": "stable/presentation-time/presentation-time.xml",
  "upstreamPhase": "stable",
  "swiftWaylandTier": "optionalFoundation",
  "generated": true,
  "publicAPI": true,
  "minimumVersion": 1
}
```

Use the manifest for docs generation and verification.

### Capability-Diff Diagnostics

As optional protocols grow, diagnosing unavailable APIs gets harder. Start
internal first:

```swift
public struct CapabilitySnapshotDiff: Equatable, Sendable {
    public let removed: [CapabilityKey]
    public let added: [CapabilityKey]
    public let changed: [CapabilityChange]
}
```

Expose publicly only if downstream clients need it.

### Surface Capability Snapshot Additions

As the next protocols land, extend internal `SurfaceCapabilitySnapshot` with
fields such as:

```swift
package let cursorShape: SurfaceCapabilityStatus
package let textInput: SurfaceCapabilityStatus
package let color: SurfaceColorCapability
package let explicitSync: SurfaceSyncCapability
```

Keep these internal until they become part of public graphics or text capability
API.

## Suggested PR Breakdown

Sprint 1 PRs:

1. `cursor-surface-runtime`
   - cursor role surface uses `SurfaceRuntime`
   - static cursor tests pass
2. `cursor-shape-protocol`
   - protocol generation, raw wrappers, capability, fallback policy
3. `cursor-scale-animation`
   - scale policy and animation state
   - owner-thread scheduling tests
4. `drag-icon-surface-substrate`
   - internal drag icon surfaces
   - source lifecycle exit tests
5. `cursor-drag-docs-and-docc`
   - README, roadmap, public API audit updates
   - stronger DocC link validation

Sprint 2 PRs:

1. `text-input-protocol-generation`
   - protocol XML, generated artifacts, shims
2. `text-input-raw-layer`
   - raw manager/input wrappers and listener owner
3. `text-input-client-state`
   - seat-scoped manager and reducer
4. `text-input-public-api`
   - conservative public session, events, and capability API
5. `text-input-integration-and-docs`
   - public integration skip/fail tests
   - DocC and public API baseline updates

## Priority Recommendation

Start with cursor surface runtime and cursor-shape before text input. It is
smaller, exercises the new `SurfaceRuntime` roles, and targets an explicitly
unsupported area. Then do text-input raw and client state as the next major
platform substrate feature.

The largest architectural risk is text-input public API shape. Keep the raw and
internal manager layers package-internal until event ordering, focus, and
surrounding-text behavior are stable.
