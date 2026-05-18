# Foundation Stabilization Sprints

This file records the next two-sprint work package after the cursor-shape,
text-input, cursor role surface, drag icon, public API gate, DocC, and
compositor-matrix work landed.

The intent is to make the existing public and internal substrate predictable
before starting explicit sync, frame pacing, color management, output control,
widgets, renderer abstractions, or new protocol families.

## Sprint 1: Public Surface And Event Lifecycle

Goal: make the new public features safe and intentional: text input,
cursor-shape and cursor surfaces, drag icons, data-transfer events, event stream
configuration, and public integration behavior.

### Text Input Request Lifecycle

- Model request-side lifecycle explicitly.
- Define behavior for inactive, enabled, focused, disabled, unknown-seat,
  unavailable-protocol, closed-window, foreign-window, repeated enable, repeated
  disable, commit before enable, and display close.
- Use `TextInputError` and `ClientError` consistently.
- Destroy or invalidate seat-scoped text-input bindings when a seat is removed.

### Text Input Event Transactions

- Make the protocol `done` boundary explicit with an internal transaction value.
- Keep public events as individual events for now.
- Test multiple preedit updates before `done`, multiple hints before `done`,
  commit plus delete in one transaction, language events outside `done`, leave
  before `done`, empty `done`, and stable event ordering.

### TextInputSurroundingText Swift Index APIs

- Keep the UTF-8 byte-offset initializer.
- Add Swift-friendly `String.Index` APIs.
- Cover ASCII, emoji, combining marks, CJK text, start and end offsets, and
  selected ranges.
- Reject invalid or stale index inputs with typed errors.

### Independent Text-Input Stream Capacity

- Add `textInputEventCapacity` to `EventStreamConfiguration`.
- Ensure text-input stream overflow is local to text-input subscribers.
- Preserve source compatibility where practical.

### Text-Input Diagnostics

- Add typed text-input diagnostics for unavailable protocol, listener problems,
  invalid event order, invalid requests, unknown protocol values, and seat
  removal.
- Publish diagnostics locally and promote them to display diagnostics where that
  matches existing event-hub behavior.
- Keep control flow independent of diagnostic strings.

### Session Event Publication Order

- Codify and test drain/publish order for output topology, window output
  membership, input routing, cursor diagnostics, text input, and data transfer.
- Document why that order is used.

### Cursor Role-Surface Lifecycle

- Test focus loss while animation is scheduled.
- Test seat removal while a cursor surface exists.
- Test cursor replacement while animation is active.
- Test hidden cursor replacing named cursor.
- Test cursor-shape path bypassing theme lookup.
- Test cursor-shape unavailable fallback to theme lookup.
- Test cursor surface destruction idempotence.
- Make stale animation cancellation explicit.

### Cursor Scale Policy

- Test no focused outputs, one focused output, multiple outputs, output removal,
  output scale changes, and large base size times scale.
- Keep the policy internal.
- Document that the current policy is output-scale-driven, not fractional
  surface-scale-driven.

### Drag Icon Lifecycle

- Cover successful icon start, failures before source creation, after source
  creation, and after icon surface creation.
- Cover source cancelled, finished, destroyed, display close, invalid pixel
  count, SHM pool allocation failure, and drag source protocol version too low.
- Add a simple solid-color `DragIconImage` constructor.
- State that XRGB8888 drag icon support is a pixel payload, not a retained drag
  UI.

### Capabilities

- Test every `WaylandCapabilities` field for absent, too-old, exact-minimum, and
  above-supported versions.
- Document the difference between display-level registry facts, seat-level
  capability, surface-level capability, and runtime-path capability.

### Protocol Manifest

- Add `swiftWaylandTier`, `apiExposure`, and `testStrategy` metadata.
- Fail verification when those fields are missing.
- Mark `tablet-v2` as a private generation dependency.

### DocC And Public API Docs

- Add conceptual articles for display lifecycle, window drawing, input versus
  text input, data transfer, cursor behavior, capabilities, diagnostics, event
  streams, drag icons, and presentation feedback.
- Verify DocC symbol links against the public symbol graph.
- Link public API audit sections to the relevant DocC article categories.

## Sprint 2: Architecture And Invariant Work

Goal: reduce risk in central types, make invariants easier to test, and prepare
future protocol work.

### DisplaySession Coordinators

- Keep `DisplaySession` as the owner-thread aggregate.
- Extract focused internal coordinators for input, output, data transfer, text
  input, and surface registry responsibilities.
- Preserve public API and behavior.

### Event Queue Vocabulary

- Normalize queue/drain names where that reduces confusion.
- Use a shared event-and-diagnostics vocabulary for data-transfer and text-input
  drains where appropriate.
- Test drain order.

### Display-Owned Public Handles

- Reduce repeated public handle identity code with an internal display-owned
  identity helper.
- Preserve equality and foreign-display behavior.

### Event Stream Configuration

- Keep configuration source-compatible where practical.
- Make each stream capacity explicit and documented.
- Avoid initializer ambiguity after text-input capacity is added.

### DisplayEventHub Tests

- Test display, input, text-input, data-transfer, presentation, and diagnostics
  paths explicitly.
- Test stream-local overflow.
- Test display close and fatal display error finishing every stream.

### Target And Layer Boundaries

- Add a script to check forbidden target imports.
- Wire the check into the normal local verification path.
- Document the enforced import rules.

### SurfaceRuntime Role Invariants

- Test role resource installation once.
- Test role resource removal before surface destroy.
- Test cursor and drag icon runtime destruction.
- Test popup and window role resource transitions.
- Test capability snapshots and output membership after destruction/removal.

### Public Error Taxonomy

- Document fatal display errors, recoverable diagnostics, unavailable feature
  errors, invalid user input, and foreign-display/window errors.
- Align behavior across clipboard, primary selection, drag, text input,
  presentation, and cursor-shape.

### Live Test Matrix

- Record real compositor facts where possible.
- Include cursor-shape, text-input, dmabuf, presentation-time, primary
  selection, and xdg-output availability.
- Keep optional protocol skips tied to exact interface names.

### Test Support

- Audit request-recording gates and surface fixtures.
- Share helpers only when they do not hide protocol details.
- Keep production code independent of test support.

### DocC Coverage

- Ensure each public feature category in the public API audit has a DocC concept
  page.
- Verify symbol links.
- Add README links to the most useful DocC pages.

### Foundation Checkpoint Criteria

- Define a nearer-term checkpoint smaller than the full foundation release
  candidate.
- Include public API gates, DocC concept docs, compositor evidence, text-input
  lifecycle, cursor and drag visual lifecycle, GPU preview reporting, no public
  GPU API, and current unsafe-island audit coverage.

## Excluded During These Sprints

- Public GPU rendering APIs.
- Output management/control APIs.
- Widgets, retained UI, gestures, renderer abstractions.
- Explicit sync and frame pacing unless required to stabilize current behavior.
