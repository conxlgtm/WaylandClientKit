# Public API Audit

This audit records the current API boundary for the experimental `WaylandClient`
product and the source-breaking preview `WaylandGraphicsPreview` product. There
is no compatibility promise yet, but public declarations in vended products
should still be treated as intentional user-facing API.

Compatibility tiers and required review process are defined in
[Compatibility Policy](compatibility-policy.md).

The minimal DocC catalog for this boundary lives in
`Sources/WaylandClient/WaylandClient.docc/WaylandClient.md`.
Identity taxonomy, raw-value visibility, and display-owned handle semantics are
tracked in [`identity-model.md`](identity-model.md) and the generated
[`identity-visibility.md`](identity-visibility.md) table.

## Products

### `WaylandClient`

Main client library product. The raw, runtime, keyboard interpretation, cursor,
graphics-core, GPU-preview, smoke-support, and test-support modules are
implementation targets for this product, not separately vended library products.

Intentionally public:

- `WaylandDisplay`
- `Window`
- `PopupSurface`
- `WindowConfiguration`
- `WindowStateSnapshot`
- `WindowRestorationSnapshot`
- `WindowDecorationPreference`
- `WindowDecorationMode`
- `PopupConfiguration`
- `PopupPositioner`
- `PopupPlacement`
- `PopupLifecycleEvent`
- `SurfaceScale`
- `SurfaceGeometry`
- `SoftwareFrameBufferID`
- `SoftwareFrameBuffer`
- `SoftwareFrameReservation`
- `SoftwareFrameGeometry`
- `PositivePixelSize`
- `SoftwareFrame`
- `SurfacePresentationIdentity`
- `SurfacePresentationFeedback`
- `PresentationFeedback`
- `PresentationTimestamp`
- `PresentationSequence`
- `PresentationFeedbackFlags`
- `WindowPresentationEvents`
- `DisplayEvent`
- `EventStreamConfiguration`
- `EventStreamIdentity`
- `DisplayDiagnostic`
- `DiagnosticSeverity`
- `DisplayEvents`
- `InputEvents`
- `DataTransferEvents`
- `TextInputEvents`
- `TextInputEventsIterator`
- `DisplayDiagnostics`
- `WaylandCapabilities`
- `ProtocolAvailability`
- `WaylandDisplayError`
- `InputEvent`
- `InputEventKind`
- `SeatCapabilities`
- `SeatID`
- `WindowID`
- `PopupSurfaceIdentity`
- public pointer, keyboard, and touch event payloads
- public relative pointer and pointer constraint payloads
- `RelativePointerSubscription`
- `RelativePointerSubscriptionID`
- `PointerGestureSubscription`
- `PointerGestureSubscriptionID`
- `PointerGestureEvent`
- `PointerSwipeGestureEvent`
- `PointerPinchGestureEvent`
- `PointerHoldGestureEvent`
- `PointerConstraint`
- `PointerConstraintID`
- `PointerConstraintRegion`
- `PointerConstraintLifetime`
- `PointerCaptureError`
- `PointerWarpError`
- public raw and interpreted keyboard event payloads
- `PointerCursor`
- `PointerCursorScalePolicy`
- `CursorRequestResult`
- `CursorConfiguration`
- `ClipboardOffer`
- `ClipboardSource`
- `ClipboardSourceConfiguration`
- `ClipboardSourcePayload`
- `ClipboardOfferIdentity`
- `ClipboardSourceIdentity`
- `ClipboardSelectionEvent`
- `DataTransferSourcePayload`
- `PrimarySelectionOffer`
- `PrimarySelectionSource`
- `PrimarySelectionSourceConfiguration`
- `PrimarySelectionOfferIdentity`
- `PrimarySelectionSourceIdentity`
- `PrimarySelectionEvent`
- `DragOffer`
- `DragSource`
- `ToplevelDrag`
- `ToplevelDragID`
- `StartedToplevelDrag`
- `DragIcon`
- `DragIconImage`
- `DragOfferIdentity`
- `DragSourceIdentity`
- `DragSourceConfiguration`
- `DragAction`
- `DragActionSet`
- `DragLocation`
- `DragEnterEvent`
- `DragMotionEvent`
- `DragLeaveEvent`
- `DragDropEvent`
- `DragOfferChangedEvent`
- `DragSourceTargetEvent`
- `DragSourceActionEvent`
- `DragSourceFinalAction`
- `DragSourceFinishedEvent`
- `DataTransferEvent`
- `DataTransferDiagnostic`
- `MIMEType`
- `OwnedFileDescriptor`
- `ByteCount`
- `TextInputSession`
- `TextInputError`
- `TextInputRequestOperation`
- `TextInputSurroundingText`
- `TextInputContentHints`
- `TextInputContentPurpose`
- `TextInputChangeCause`
- `TextInputAction`
- `TextInputPreeditHintKind`
- `TextInputPreeditHint`
- `TextInputFocusEvent`
- `TextInputPreeditEvent`
- `TextInputCommitEvent`
- `TextInputDeleteSurroundingTextEvent`
- `TextInputActionEvent`
- `TextInputLanguage`
- `TextInputLanguageEvent`
- `TextInputDoneEvent`
- `TextInputDiagnostic`
- `TextInputDiagnosticOperation`
- `TextInputEvent`
- `ForeignToplevelID`
- `ForeignToplevelSnapshot`
- `ForeignToplevelEvent`
- `ForeignToplevelListSnapshot`
- `OutputManagementHeadID`
- `OutputManagementModeID`
- `OutputManagementMode`
- `OutputManagementHead`
- `OutputManagementSnapshot`
- `ClientError`

Current user-facing contract:

- `WaylandClient` is the only supported import for downstream users.
- Display connection, window creation and close, request-redraw, software
  XRGB8888 drawing, basic pointer/keyboard/touch events, interpreted keyboard
  payloads, server-side decoration negotiation, scale-aware window geometry,
  popup surfaces, restoration snapshots, presentation feedback, regular
  clipboard selection, primary selection, receive-side and source-side
  drag-and-drop data transfer, drag icon surfaces, xdg activation, relative
  pointer, pointer lock/confine, pointer warp, tablet input facts, cursor
  requests, text-input sessions and events, foreign toplevel facts,
  output-management preview facts, compositor session capability,
  diagnostics, and terminal display errors are the current product
  surface.
- Public event and diagnostic enums are machine-matchable. String descriptions
  are derived display text, not control-flow payloads.
- Managed identities are returned by the library and cannot be fabricated by
  external clients. Registry names, protocol serials, touch IDs, protocol object
  IDs, and opaque protocol tokens remain publicly constructible because callers
  may need to round-trip those compositor facts.
- Raw keycodes, raw pointer button values, raw axis values, and unknown future
  protocol values are intentionally preserved when useful to clients.
- Interpreted keyboard events expose local keyboard text through
  `KeyboardTextResult`. Shortcut matching should still use `keySymbols`,
  `primaryKeySymbol`, and modifiers. Text-input/IME output is reported through
  the separate text-input event stream.
- Raw keymap bytes, raw file descriptors, raw proxies, listener owners, event
  queues, SHM pool internals, and owner-thread executor machinery are not
  product API.
- `SoftwareFrame` is a scoped borrowed drawing surface. User code may draw
  during the callback and may not retain frame storage beyond that callback.
  `SoftwareFrameBufferID` gives each reusable software buffer an opaque public
  identity, and `SoftwareFrameBuffer` exposes scoped contiguous XRGB8888 byte
  spans, stride, and geometry without exposing raw Wayland or SHM handles.
  `SoftwareFrameReservation` lets async preparation observe the selected
  software buffer identity and geometry before the final scoped draw borrow.
- Window sizes are logical surface sizes. `SurfaceGeometry` records the
  logical size, buffer-pixel size, and exact `SurfaceScale` used by the
  current SHM frame.
- Output management is read-only public API. The former proposal, test, and
  apply operations were removed because their only meaningful input was a
  snapshot serial and they could not express a requested configuration change.
  A package-only current-state test remains for protocol smoke coverage.
- Compositor session management is capability-only public API. The former
  one-roundtrip event snapshot was removed because it destroyed the session
  before later replacement events or surface attachment could be observed.
- Regular clipboard means `wl_data_device_manager` selection offers and sources.
- `WaylandDisplay.capabilities()` reports the connection-start set of compositor support
  for regular clipboard, drag-and-drop, drag action negotiation, primary
  selection, server-side decorations, xdg-output, viewporter, presentation time,
  fractional scaling, cursor-shape, xdg activation, relative pointer, pointer
  constraints, pointer warp, tablet input, compositor session management,
  text-input, and linux-dmabuf without binding new protocol objects. Managers
  advertised later require a new connection; removing a startup manager makes
  the matching capability unavailable and retires any retained proxy.
- Primary selection means `zwp_primary_selection_device_manager_v1` offers and
  sources. It is selection-driven, focus-sensitive, and serial-scoped.
- Drag-and-drop means `wl_data_device_manager` target offers and local sources,
  including MIME negotiation, action negotiation when the compositor supports
  version 3, source lifecycle events, bounded reads, and local source
  cancellation. Drag icon surfaces are managed XRGB8888 surfaces attached to a
  local source-side drag request.
- Text input means `zwp_text_input_manager_v3` seat-scoped sessions and
  `zwp_text_input_v3` events. Surrounding text offsets are UTF-8 byte offsets at
  the protocol boundary. Input-panel show/hide requests are version-gated v2
  hints that compositors may ignore. Preedit, delete, commit, action, language,
  preedit-hint, and done events are typed public facts.
- Compositor session management means `xdg_session_manager_v1` advertisement
  reporting through `WaylandCapabilities.compositorSessionManagement`. Raw
  lifecycle objects stay package-internal until a durable public owner can
  observe later events and attach surfaces. Local restore policy remains
  framework-owned.
- Relative pointer and pointer constraints mean
  `zwp_relative_pointer_manager_v1` and `zwp_pointer_constraints_v1`.
  WaylandClientKit exposes capability facts, relative motion events, typed
  lock/confine lifecycle events, and window-scoped lock/confine requests without
  deciding application pointer-capture policy.
- Pointer warp means `wp_pointer_warp_v1`. Public requests are managed-window,
  seat, serial, and logical-position scoped. They report typed unavailable,
  foreign-window, closed-window, unknown-seat, pointer-unavailable, invalid-position,
  and request-failed errors without exposing raw warp, pointer, surface, or queue
  objects. Compositor policy may still ignore or reject a request.
- Tablet input means `zwp_tablet_manager_v2` device, tool, and pad facts,
  including proximity, motion, pressure, tilt, rotation, slider, wheel,
  distance, tool buttons, pad buttons, frame boundaries, and pad group-added
  notifications. Events are seat-scoped and target-resolved where the protocol
  provides a surface. Public pad ring, strip, and dial child-control events are
  intentionally deferred. WaylandClientKit does not define drawing, gesture,
  brush, stroke, eraser behavior, or canvas policy.
- Cursor requests cover compositor cursor-shape requests, named theme cursors,
  hidden cursors, static XRGB8888 custom cursor images, and output-aware theme
  scale policy. Animated custom cursors are public value types built from
  validated cursor images and positive frame durations, WaylandClientKit keeps
  frame scheduling, SHM buffers, and cursor surfaces private.
- Presentation feedback means `wp_presentation` feedback for managed surfaces.
  Frame callbacks, presentation feedback, graphics-preview scheduling requests,
  and explicit sync remain separate concepts.
- Output topology means `WaylandDisplay.outputs()` and
  `WaylandDisplay.outputTopology()` expose current output snapshots, stable
  connection-local output identities, logical geometry, scale, transform,
  physical size, names, descriptions, and surface output membership facts.
  `outputTopology()` returns the same output snapshot array sorted by identity.
  WaylandClientKit reports output facts, it does not apply monitor settings or
  own display-configuration policy.
- GPU and GBM/EGL work remains package-internal and is surfaced only through the
  separate preview product. There is no public renderer, swapchain, drawable, or
  GPU buffer API in `WaylandClient`. Renderer-owned dmabuf descriptor
  construction, registration, submission, and release tracking are package-
  scoped preview helpers.
- `WaylandGraphicsRuntimePath` exposes renderer-neutral stage facts for
  surface feedback, render-node selection, dmabuf import, and buffer lifecycle.
  These are status values only and do not expose GBM/EGL/DRM/dmabuf handles.

### `WaylandGraphicsPreview`

Preview library product. This product is renderer-neutral and source-breaking
until the graphics backing foundation is promoted.

Intentionally public:

- `WaylandGraphicsProtocolAvailability`
- `WaylandGraphicsFramePacingAvailability`
- `WaylandGraphicsColorMetadataAvailability`
- `WaylandGraphicsSurfaceCapabilities`
- `WaylandGraphicsPresentationPolicy`
- `WaylandGraphicsFallbackDisposition`
- `WaylandGraphicsReason`
- `WaylandGraphicsBackingDecision`
- `WaylandGraphicsRuntimeStatus`
- `WaylandGraphicsPacingStatus`
- `WaylandGraphicsMetadataStatus`
- `WaylandGraphicsRuntimePath`
- `WaylandGraphicsConfiguration`
- `WaylandGraphicsSynchronizationPolicy`
- `WaylandGraphicsPacingPolicy`
- `WaylandGraphicsFrameSchedule`
- `WaylandGraphicsFramePacingRequest`
- `WaylandGraphicsMetadataPolicy`
- `WaylandGraphicsPresentationFeedbackPolicy`
- `WaylandGraphicsDamageRegion`
- `WaylandGraphicsFrameMetadata`
- `WaylandGraphicsContentType`
- `WaylandGraphicsPresentationHint`
- `WaylandGraphicsAlphaModifier`
- `WaylandGraphicsColorAlphaMode`
- `WaylandGraphicsColorRepresentation`
- `WaylandGraphicsXRGBColor`
- `WaylandGraphicsSurfaceGeneration`
- `WaylandGraphicsExternalConfigurationID`
- `WaylandGraphicsExternalBufferID`
- `WaylandGraphicsExternalSubmissionID`
- `WaylandGraphicsExternalSyncTimelineID`
- `WaylandGraphicsExternalSyncTimeline`
- `WaylandGraphicsExternalSyncPoint`
- `WaylandGraphicsExternalAcquireSynchronization`
- `WaylandGraphicsRenderNode`
- `WaylandGraphicsExternalSynchronizationAvailability`
- `WaylandGraphicsExternalAlphaMode`
- `WaylandGraphicsExternalBufferConfiguration`
- `WaylandGraphicsFrameContract`
- `WaylandGraphicsExternalBuffer`
- `WaylandGraphicsDRMFormat`
- `WaylandGraphicsDRMFormatModifier`
- `WaylandGraphicsExternalBufferPlane`
- `WaylandGraphicsExternalBufferPlanes`
- `WaylandGraphicsExternalBufferDescriptor`
- `WaylandGraphicsClearFrame`
- `WaylandGraphicsSubmittedFrame`
- `WaylandGraphicsFrameResult`
- `WaylandGraphicsExternalRetirementReason`
- `WaylandGraphicsExternalReleaseMechanism`
- `WaylandGraphicsExternalSyncobjTimelinePoint`
- `WaylandGraphicsExternalReleaseSynchronization`
- `WaylandGraphicsExternalBufferLifecycle`
- `WaylandGraphicsExternalReleaseResult`
- `WaylandGraphicsExternalPresentationFeedbackIdentity`
- `WaylandGraphicsExternalPresentationFeedbackResult`
- `WaylandGraphicsExternalBufferSubmissionReceipt`
- `WaylandGraphicsExternalBufferRenderLease`
- `WaylandGraphicsError`
- `WaylandGraphicsWindowBacking`
- `WaylandGraphicsFrameLease`
- `WaylandDisplay.graphicsSurfaceCapabilities()`
- `WaylandDisplay.graphicsRuntimePath(policy:)`
- `WaylandDisplay.graphicsBackingDecision(policy:)`
- `WaylandDisplay.createGraphicsWindowBacking(windowConfiguration:graphicsConfiguration:)`

Current preview contract:

- The product reports renderer-neutral graphics capabilities, projected and
  observed runtime-path facts, software fallback decisions, and required-GPU
  unavailability.
- `WaylandGraphicsPresentationPolicy` is the sole source of truth for software,
  managed GPU, or external GPU presentation and its fallback disposition.
  Contradictory mode/fallback combinations and the former lossy mutable backing
  projection are not public. This is an intentional source break in the preview
  product.
- `WaylandGraphicsReason` is shared by fallback and failed runtime statuses;
  their status case records the disposition without a duplicate reason enum or
  duplicate mapping switch.
- External configuration, buffer, submission, and synchronization timeline IDs
  are issued by WCK. Callers may compare and retain the typed values, but their
  constructors and raw values remain package-only.
- The managed preview submission path can create a window backing, lease a
  frame, attempt a package-internal GPU clear-frame path, fall back to software
  when policy allows, submit arbitrary software drawing, return a typed frame
  result, and cancel or close resources without exposing raw protocol or renderer
  objects.
- The external-buffer import path is public source-breaking preview API for
  renderer-owned one-to-four-plane dmabuf images. Public descriptor and sync
  timeline values are move-only and consume `OwnedFileDescriptor` ownership;
  public API does not expose raw Wayland proxies, GBM/EGL objects, borrowed
  descriptor integers, or pointers. External configurations expose selected
  format/modifier facts and render-node device identity bytes, leaving native
  device opening/allocation to the renderer. Registration imports a descriptor
  once, frame leases reserve registered buffers, render leases submit implicit
  or explicit synchronization, and receipts report submission identity, buffer
  identity, contract generation, runtime facts, release mechanism, typed release
  synchronization facts, and terminal compositor-release result. Explicit
  release facts expose WCK's release timeline ID and point without exposing raw
  protocol or DRM objects; they are diagnostics, not reuse authority. Only a
  `.released` result is compositor release evidence. A failed result requires
  the renderer to keep its allocation alive until backing close; explicit
  release polling failure automatically fails the external runtime path and
  closes the backing before completing that receipt.
- Dma-buf registration and sync-timeline import revalidate backing epoch, window
  identity, surface generation, synchronization, and external configuration
  after suspension. Invalidated imports destroy or remove unpublished raw
  resources and return a typed closed-backing or stale-contract error.
- External-buffer receipts correlate presentation feedback to the same
  submission and buffer IDs as the release receipt. The presentation waiter is
  independent from release, completes exactly once when requested, and never
  unlocks renderer buffer reuse.
- Imported renderer acquire timelines are backing-scoped. WCK consumes the file
  descriptor, keeps the compositor mapping alive until backing close, and
  removes imported acquire mappings during backing cleanup. There is no public
  raw proxy, borrowed descriptor, or per-frame import requirement.
- `WaylandGraphicsFrameLease.contract` exposes the generation-bound geometry,
  synchronization availability, runtime-path snapshot, and initial normalized
  XRGB8888/ARGB8888 external-buffer candidates needed before rendering.
- `WaylandGraphicsError.staleFrameContract` and
  `WaylandGraphicsError.externalBufferUnavailable` remain public typed failures
  for stale frame contracts and external-buffer ownership checks. Stale and
  unavailable external-buffer failures include generation or lifecycle details.
- Managed GPU failures preserve public typed reasons including missing
  per-surface dmabuf feedback, GBM allocation failure, and explicit-sync setup,
  submission, or release failure, display-level dmabuf advertisement alone is
  not reported as active GPU backing.
- Synchronization and pacing policies are active runtime requests for graphics
  preview submissions, and `WaylandGraphicsFrameSchedule` makes them
  per-frame caller-visible preview scheduling inputs. `implicitOnly` avoids
  explicit sync objects, `preferExplicit` falls back to implicit sync with a
  runtime reason only before explicit sync is installed or active on the
  surface, and `requireExplicit` fails instead of silently falling back. A
  software presentation policy cannot request explicit synchronization.
  `fifo` and `commitTiming` apply submit constraints on managed GPU
  and software/fallback commits when advertised, FIFO commits prime with
  `set_barrier` before later commits wait and re-prime. Missing pacing
  protocols report fallback or typed failure facts. Live compositor evidence
  currently proves explicit sync and FIFO active. Commit timing remains an
  implementation path with typed fallback/failure evidence, not active live
  proof.
- It does not expose raw Wayland proxies, EGL/GBM/DRM objects, syncobj handles,
  file-descriptor handles, SHM pools, scene rendering, swapchains, drawables, or
  raw color-management/image-description protocol objects.
- Public frame metadata is intentionally narrow. Content type and presentation
  hint map to safe surface commit metadata when their protocols are available
  and `metadataPolicy` permits metadata. Preferred-but-unavailable metadata is
  omitted from the commit and reported with protocol-specific public fallback
  reasons. Alpha and color representation are preview protocol facts rather
  than renderer policy. Public color-description metadata is deferred until a
  managed image-description producer exists. Full-frame damage is the supported
  default. Partial damage is
  accepted for managed software submissions, converted to `SurfaceDamageRegion`,
  mapped from logical surface coordinates to active buffer damage coordinates,
  and rejected as `WaylandGraphicsError.invalidDamageRegion` when it has no
  surface intersection.
- Presentation feedback policy can request feedback when available or require
  it before creating a managed backing. Feedback observations still arrive on
  `WindowPresentationEvents`, frame submission results only report whether
  feedback was requested for that submit, not whether it was later observed.
- Downstream code that wants this boundary imports `WaylandGraphicsPreview`
  explicitly, importing `WaylandClient` alone does not opt into renderer-facing
  preview API.

Intentionally package-internal:

- `DisplaySession`
- `TopLevelWindow`
- `WaylandGraphicsCore`
- `WaylandGPUPreview`

Notes:

- `WaylandDisplay` is the high-level async surface. It is an actor backed by a
  dedicated Wayland owner-thread executor. The executor owns the integrated pump loop.
  display/input event streams are passive subscribers and do not drive Wayland dispatch.
- Display streams terminate normally on explicit close and terminate with
  `WaylandDisplayError` on fatal display failure or per-subscriber overflow.
- `EventStreamConfiguration` controls display, input, text-input, data-transfer,
  and presentation stream capacities independently.
- Nonterminal runtime degradation is surfaced through `DisplayEvent.diagnostic`.
  Input-specific diagnostics also remain available on `inputEvents`.
- `Window` is the ergonomic async handle. Windows are still addressable by `WindowID`,
  and teardown is routed through `WaylandDisplay.closeWindow(_:)` or
  awaited `WaylandDisplay.close()`. Display-level close drains registered
  window-close observers before destroying surfaces so graphics release waiters
  terminate with a closed-backing result.
- `PopupSurface` is the public popup handle. Popup lifecycle display events carry
  the popup identity and parent window identity.
- `WindowPresentationEvents` is a public async sequence for presentation
  feedback requested through a managed window. A discarded result is distinct
  from a presented result with timestamps and feedback flags.
- Every public event sequence creates an independent broker subscription in
  `makeAsyncIterator()`. Buffering begins at iterator creation; copied sequences
  do not split one queue, and cancellation or overflow remains local to one
  iterator.
- `Window.decorationMode` reports the current effective xdg-decoration mode when
  the compositor supports `zxdg_decoration_manager_v1`. Mode absence is explicit
  as `.unavailable`.
- `Window.geometry` reports the current logical surface size, buffer-pixel size,
  and scale. The value is derived from the current xdg configure size and the
  active preferred integer or fractional surface scale.
- The runtime is single-thread-affine. Thread-affine session/window entry points are
  package implementation details. Downstream users should go through `WaylandDisplay`
  and `Window`.
- `TopLevelWindow` owns managed toplevel surface presentation for SHM software
  drawing and package-internal graphics-preview buffer commits, it is not
  public API.
- `SoftwareFrame` is noncopyable and borrowed by drawing callbacks. User code can draw
  through row spans or a scoped `SoftwareFrameBuffer` byte-span borrow during the
  callback, but cannot copy the frame out and mutate the SHM storage after presentation.
- `SoftwareFrameBufferID` is hashable and sendable, but opaque. It identifies the
  reusable client-side software buffer, not the content revision stored in that
  buffer and not any raw Wayland or shared-memory handle.
- `SoftwareFrameReservation` is a sendable fact snapshot for the preparation
  stage of `Window.show` and `Window.redraw`. The reserved mutable memory remains
  managed by WaylandClientKit until the final draw closure borrows a
  `SoftwareFrame`; reservation does not expose raw SHM storage.
- `SoftwareFrame.width` and `SoftwareFrame.height` are buffer-pixel dimensions.
  `SoftwareFrame.geometry.logicalSize` remains the surface-local logical size
  used for layout and input coordinate interpretation.
- `KeyboardEvent.raw` carries raw protocol keyboard facts.
- `KeyboardEvent.interpreted` carries xkbcommon-backed key symbols, simple UTF-8 values,
  modifier state updates, repeat info, and diagnostics.
- UTF-8 values from interpreted key events are not text-input protocol output.
- Cursor management is display-level. `PointerCursor` names theme cursors, and
  `WaylandDisplay.setPointerCursor(_:)` applies the desired cursor to focused seats.
  Explicit cursor changes throw when the cursor stack cannot fulfill the request.
  Cursor-shape is used when advertised and the requested cursor maps to a known
  compositor shape, otherwise the theme cursor path remains the fallback. Static
  custom cursor images use validated XRGB8888 pixels and private SHM-backed
  cursor surfaces. Animated custom cursor values reuse that image validation and
  expose no raw cursor surface, SHM pool, buffer, timer, or queue handles.
  Diagonal resize convenience presets are deferred until cursor theme names are
  verified across KDE, GNOME, Sway/wlroots, and Weston, frameworks may use
  custom names such as `nw-resize`, `ne-resize`, `sw-resize`, and `se-resize`.
- Subsurface management is window-owned. Public handles expose creation,
  software show/redraw, regions, position, stacking, sync/desync, close,
  redraw-state, and geometry without exposing raw `wl_surface` or
  `wl_subsurface` objects. Parent-applied state is committed by WaylandClientKit
  after managed creation, movement, stacking, and synchronized child surface
  updates. Sync/desync mode changes are immediate protocol requests and do not
  commit the parent. Self-stacking and cross-parent stacking are typed display
  errors.
- Relative pointer requests reject duplicate active subscriptions for the same
  seat with `PointerCaptureError.relativePointerAlreadySubscribed` before
  sending protocol requests. Pointer lock/confine requests reject duplicate
  constraints for the same surface and seat with
  `PointerCaptureError.alreadyConstrained` before sending protocol requests.
  Pointer constraint input events publish lifecycle transitions rather than raw
  protocol vocabulary, so one-shot defunct state and persistent inactive state
  are distinct public facts.
  Pointer capture state is discarded when a seat loses pointer capability so
  later hotplug or compositor capability churn can create fresh subscriptions
  and constraints. Seats without an active pointer child report
  `PointerCaptureError.pointerUnavailable` for relative pointer, lock, and
  confine requests before raw protocol requests are sent. Cursor hints are
  validated before Wayland fixed-point conversion and report
  `PointerCaptureError.invalidCursorHint` for non-finite or out-of-range
  coordinates.
- Clipboard offers are seat-scoped. `ClipboardOffer.read` performs a bounded read
  with a timeout, and `ClipboardSourceConfiguration` describes local regular
  clipboard payloads.
- Drag offers are seat-scoped and serial-bound to the current drag operation.
  `DragOffer.read` uses the same bounded transfer rules as clipboard and primary
  selection reads. `DragSourceConfiguration` requires non-empty MIME payloads
  and known drag actions. `DragIconImage.solid(size:color:)` is a convenience
  constructor for a simple XRGB8888 drag icon payload.
- `TextInputSession` is seat-scoped. Enabling text input targets a managed
  window, request methods require an enabled or focused session, and `commit()`
  sends the protocol commit request. `TextInputSurroundingText` supports both
  protocol UTF-8 byte offsets and Swift `String.Index` construction. `disable()`
  finalizes the disable request, callers should commit pending enabled-state
  changes before disabling and should not call `commit()` after `disable()`.
  Input-panel show/hide requests are v2 hints and can be ignored by the
  compositor.
  `WaylandDisplay.textInputEvents` is separate from `inputEvents`, and
  text-input diagnostics can publish on both text-input and display diagnostic
  streams.
- `WaylandCapabilities` is a registry-discovery snapshot. It lets applications
  branch before requesting optional features, but request APIs still throw typed
  availability errors because Wayland globals can be removed after discovery.
  `xdgActivation` reports `xdg_activation_v1` advertisement. Public activation
  APIs request opaque tokens and send managed-window activate requests without
  exposing raw activation proxies. Activation remains compositor-mediated:
  serial, surface, and app ID values are request facts, not a focus guarantee.
  `ActivationAppID` and `ActivationSerialContext` keep invalid app IDs and
  half-formed seat/serial pairs out of `ActivationTokenRequest`. Caller
  cancellation reports `ActivationError.cancelled`, while display teardown still
  reports `ActivationError.displayClosed`.
  The previous `WaylandCapabilities` initializer remains available and defaults
  `xdgActivation` to unavailable for source compatibility.
- `WindowRestorationSnapshot` is a platform-fact bundle for framework-owned
  local restoration. It includes window identity, title, app ID, geometry,
  state, decoration mode, and output membership without defining scene,
  document, placement, or restore policy.
- Primary selection offers are seat-scoped and expire when the compositor sends
  a null selection or focus changes. `PrimarySelectionOffer.read` uses the same
  bounded transfer rules as clipboard reads, and `PrimarySelectionSourceConfiguration`
  describes local primary-selection payloads.
- `WindowDecorationPreference.preferServerSide` is the default because WaylandClientKit
  does not draw client-side titlebars. `preferClientSide` requests no server-side
  decorations. Applications remain responsible for any custom chrome they want.
- `WindowDialog`, `KeyboardShortcutsInhibitor`, and `ToplevelDrag` expose
  protocol-shaped desktop relationship requests only. WaylandClientKit does not
  implement modal event filtering, sheet/alert behavior, shortcut policy, or
  drag/drop policy.
- `KeyboardShortcutsInhibitorEvent` reports compositor active/inactive facts.
  Requesting inhibition is not treated as proof that shortcuts are inhibited.
- Foreign toplevel list exposes read-only event-backed snapshots and
  add/update/remove facts. Titles, app IDs, and identifiers are optional
  privacy-sensitive compositor facts. There is no public close, minimize, focus,
  or management API.
- Output management exposes preview event-backed head/mode snapshots and an
  explicit current/no-op configuration proposal path. Test/apply calls are
  compositor-specific preview requests and never run from the default smoke
  path. There is no general display-settings framework API.
- `WaylandDisplay.withConnection` does not eagerly require a cursor theme to load.
- `DisplayConfiguration` and the convenience `WaylandDisplay.withConnection`
  overload require an application ID. `WindowConfiguration.default` has a plain
  title and no demo identity; a per-window app ID is only an explicit override.
  Cursor theme loading is deferred until a visible cursor image is first needed.
- `WaylandDisplay.withConnection`, `Window.show`, and `PopupSurface.show` use finite
  default waits. Callers must opt into longer waits by passing an explicit timeout.
- All Swift targets enable Swift strict memory-safety diagnostics as errors.
  Unsafe storage is confined to explicit C, pointer, and executor boundary wrappers.

## Implementation Targets

These targets are package-internal architecture units:

- `WaylandRaw`: low-level protocol-shaped wrappers, raw input capture, and copied keymap payloads.
- `WaylandKeyboard`: xkbcommon-backed interpretation of copied `xkb_v1` keymaps.
- `WaylandCursor`: wayland-cursor theme loading and cursor image lifetime handling.
- `WaylandRuntime`: owner-thread executor and runtime event loop.
- `WaylandGraphicsCore`: package-internal GBM, DRM, EGL, and GLES substrate.
- `WaylandGPUPreview`: package-internal dmabuf import and GPU window presentation.
- `WaylandSmokeSupport`: shared smoke-test support.
- `WaylandTestSupport`: test-only support code.

They may contain `public` declarations for cross-target compilation mechanics, but they are
not vended as package library products.

Run `swift run wck api dump` during public API review and compare the
output against this audit. Any new public declaration in `WaylandClient` should
be classified as product API, raw-preserving API, diagnostic/error API, or
temporary API to remove before a public compatibility policy exists.

## Stable Raw-Preserving Values

These are expected to remain public because applications need protocol facts:

- raw keyboard keycodes,
- raw keyboard key state values,
- raw pointer button values,
- raw pointer axis values,
- touch IDs and coordinates,
- seat/window IDs,
- unknown future raw values in public event wrappers.

These are not expected to become public product API:

- `RawOwnedProxy`,
- raw Wayland object pointers,
- raw event queues,
- raw listener owners,
- raw keymap file descriptors or mmap data,
- SHM pool and buffer implementation details,
- executor or event-loop internals.

## Access Level Rules

Use the narrowest access level that works:

```text
private
internal
package
public
```

Use `package` for cross-target implementation details.

Use `public` only for downstream package API.

## Sendable Review

Public event payloads are value-shaped and can be `Sendable`.

Do not add `@unchecked Sendable` without a documented exception and review. Current lint rules reject it.

## Development Contract

The public API may break while WaylandClientKit is experimental.

Before treating a public declaration as intentional:

1. Run `swift run wck api dump`.
2. Review all new `WaylandClient` public declarations.
3. Confirm non-product public declarations are still outside the manifest's
   library products.
4. Update this audit if the current public contract changes.
