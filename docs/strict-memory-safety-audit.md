# Strict Memory Safety Audit

WaylandClientKit treats raw Wayland objects and shared-memory mappings as explicit unsafe islands. Public client-facing APIs should not expose raw C pointers or mmap lifetimes directly.

## Shared Memory and Borrowed Buffers

Remaining unsafe constructs:

- `RawBorrowedBuffer` stores a borrowed `wl_buffer` pointer returned by cursor theme APIs.
- `RawBuffer` stores an `UnsafeMutableRawBufferPointer` into an mmap-backed SHM pool.
- `MappedRegion` owns the mmap base address and unmaps it in `deinit`.
- `RawSurface` passes owned or borrowed buffers to `wl_surface.attach`.

Audit invariant:

- A `RawSharedMemoryPool` owns its mmap for at least as long as any `RawBuffer` created from that mapping.
- `RawBuffer.withUnsafeMutableBytes` is the only normal way for client code to borrow buffer memory.
- `SoftwareFrame` validates dimensions, stride, and byte count before exposing row spans
  or a scoped `SoftwareFrameBuffer` byte-span borrow to redraw code.
- `SoftwareFrameBufferID` is derived from a monotonically assigned private `RawBuffer`
  token. Public callers can compare buffer reuse without receiving raw pointers, file
  descriptors, Wayland objects, object addresses, or mmap ownership.
- `SoftwareFrameReservation` carries sendable geometry and buffer-identity facts
  while the actual reserved SHM lease stays inside the managed window. Failed or
  canceled preparation discards the internal reservation before returning control
  to user code.
- Borrowed cursor buffers are never written by WaylandClientKit. They are only attached to cursor surfaces.

Tests:

- `SharedMemoryLayoutTests` covers layout overflow and buffer lifecycle state.
- Window presentation tests cover draw failure, frame failure, buffer release, and close cleanup behavior at the model boundary.

## Raw Proxy Ownership

Remaining unsafe constructs:

- `RawOwnedProxy` owns an `OpaquePointer` and the matching C destroy/release function.
- `RawSurface` delegates local destroy idempotence to `RawOwnedProxy`.

Audit invariant:

- Every `RawOwnedProxy` calls its destroy function at most once.
- Proxy adoption validates queue ownership before wrapping a proxy.
- Raw surfaces destroy their Wayland proxy through the same ownership wrapper used by other raw proxy owners.

## Listener Callback Ownership

Remaining unsafe constructs:

- `CListenerStorage` allocates C callback tables and stores an unretained pointer
  to itself in each listener `data` field.
- `CallbackBoxStorage` keeps the Swift owner reachable while the listener is
  valid.
- Seat, pointer, keyboard, touch, data-device, XDG, foreign-toplevel,
  output-management, session-management, buffer-release, frame callback,
  scale-extension, cursor-shape, and text-input listeners recover Swift owners
  from C callback payloads.
- `RawInputChildProxy` keeps pointer, keyboard, and touch listener owners alive
  until the child proxy is destroyed.

Audit invariant:

- A listener owner remains strongly reachable for as long as Wayland can invoke
  the registered callback.
- Listener storage is invalidated before the owned proxy is destroyed or before
  the callback lifecycle reaches a terminal state.
- Callback storage remains allocated until any active callback returns, even
  when the callback destroys or cancels its own registration.
- A callback after listener invalidation is a fatal raw invariant failure, not a
  silently ignored event.

Tests:

- `CallbackBoxTests` covers opaque pointer round trips, invalidation, weak-owner
  loss, fatal invariant routing, and reentrant release during an active callback.
- `FrameCallbackRegistrationTests` covers install failure cleanup, cancel
  idempotence, one-shot frame completion, callback-owner lifetime during
  reentrant release, and listener invalidation while the callback payload is
  still alive.
- `RawSeatLifecycleTests` covers pointer, keyboard, and touch callback delivery
  after child listener installation, child creation failure cleanup, and child
  proxy release on capability removal.

## Text-Input Boundary

Remaining unsafe constructs:

- `RawTextInputManager` and `RawTextInput` wrap `zwp_text_input_manager_v3` and
  `zwp_text_input_v3` proxies returned by C shims.
- `RawTextInputOwner` owns the listener callback table and forwards compositor
  text-input events to `TextInputManager`.
- Text-input request strings cross from Swift into C through NUL-terminated
  UTF-8 storage during `set_surrounding_text`.

Audit invariant:

- Text-input objects are seat-scoped and destroyed when their binding or display
  session is shut down.
- Listener storage is cancelled before destroying the raw text-input proxy.
- Surrounding text rejects embedded NUL bytes before crossing the C request
  boundary.
- Public surrounding-text requests carry validated UTF-8 cursor and anchor
  offsets so stale `String.Index` values cannot trap before typed error
  handling.
- Preedit, delete-surrounding-text, commit-string, action, and done events are
  grouped by the protocol's `done` transaction event before publication.
- Late text-input callbacks after manager shutdown do not publish new events.

Tests:

- `TextInputStateTests` covers transaction grouping, focus reset, and immediate
  language events.
- `TextInputSurroundingTextRequestTests` covers UTF-8 offset validation,
  overflow, and NUL rejection.
- `TextInputManagerTests` covers request forwarding, unavailable errors,
  target resolution, binding destruction, and late callback behavior.
- `DisplayEventHubTextInputTests` covers delivery on the text-input stream.

## Foreign Toplevel, Output Management, And Session Boundaries

Remaining unsafe constructs:

- `RawForeignToplevelList` and `RawForeignToplevelHandle` wrap
  `ext_foreign_toplevel_list_v1` and handle proxies and listener owners.
- `RawWlrOutputManager`, `RawWlrOutputHead`, `RawWlrOutputMode`, and
  `RawWlrOutputConfiguration` wrap wlroots output-management proxies and
  listener owners.
- `RawCompositorSessionManager`, `RawCompositorSession`, and
  `RawCompositorToplevelSession` wrap staging `xdg_session_manager_v1`,
  `xdg_session_v1`, and `xdg_toplevel_session_v1` proxies returned by C shims.
- Listener owners bridge foreign toplevel updates, output head/mode/configuration
  updates, and compositor-created/restored/replaced callbacks into typed raw
  events.

Audit invariant:

- The public APIs expose value snapshots and protocol facts, not raw proxies or
  listener owners.
- Listener storage is cancelled before the corresponding raw proxy is destroyed.
- Output-management head and mode destroy paths are version-gated: v3+ uses the
  protocol `release` request and older bindings fall back to local proxy destroy.
- Session-management preview events remain protocol facts. Scene/document
  identity and local restore policy stay framework-owned.

Tests:

- `RawCompositorSessionLifecycleTests` covers manager, session, and toplevel
  session destroy idempotency, listener event mapping, listener cancellation,
  late events after destroy, and child toplevel cleanup.
- Raw foreign-toplevel and output-management tests cover listener mapping,
  destroy/release behavior, and configuration request paths.
- `WaylandCapabilitiesTests` covers `xdg_session_manager_v1` advertisement and
  negotiated-version reporting.
- C shim verification covers the request/listener declarations compiled into
  the package.

## Tablet Input Boundary

Remaining unsafe constructs:

- `RawTabletManager`, `RawTabletSeat`, `RawTablet`, `RawTabletTool`, and tablet
  pad child wrappers own `zwp_tablet_manager_v2`, `zwp_tablet_seat_v2`,
  `zwp_tablet_v2`, `zwp_tablet_tool_v2`, and pad protocol proxies returned by
  generated C helpers.
- Tablet listener owners recover Swift state from C callback payloads and
  forward typed raw tablet events into the public input router.

Audit invariant:

- Tablet objects are seat-scoped and destroyed when the seat disappears or the
  display session shuts down.
- Listener storage remains reachable while the raw tablet proxy can emit events
  and is invalidated before destroy.
- Unknown tablet tool capabilities, tool types, bus types, and pad button facts
  are preserved as raw values where needed instead of trapping. Tablet pad
  group proxies are tracked for deterministic teardown, public ring, strip, and
  dial child-control events are deferred until their event surface is designed.
- Public tablet events expose only typed input facts and target identities, not
  raw protocol objects, queues, pointers, or device handles.

Tests:

- `InputRouterTabletTests` covers target routing, seat removal, surface cleanup,
  unknown capability preservation, and device/tool/pad event projection from
  raw tablet event facts.
- `RawTabletLifecycleTests` covers compositor removal events destroying tracked
  tablet, tool, pad, and pad-group protocol objects exactly once.
- Shim verification covers the Swift-facing tablet listener and destroy helper
  declarations against their C implementations.

## Cursor And Drag Visual Surfaces

Remaining unsafe constructs:

- `RawCursorShapeManager` and `RawCursorShapeDevice` wrap compositor-managed
  cursor-shape protocol objects.
- `CursorRoleSurface` owns a `wl_surface` used as the pointer cursor image
  surface and routes commits through `SurfaceRuntime`.
- `DragIconRoleSurface` owns a `wl_surface` and SHM buffer used as a source-side
  drag icon surface.
- `SurfaceRoleReadinessSnapshot` records which managed roles accept shared
  surface operations, making cursor and drag icon exclusions explicit in tests.

Audit invariant:

- Cursor-shape device listeners and raw proxies are destroyed with the cursor
  manager backend.
- A cursor request uses compositor cursor-shape only when the requested
  `PointerCursor` maps to a known protocol shape, otherwise the theme-surface
  path remains the fallback. Static custom cursor images allocate private SHM
  buffers and retain the image owner through the cursor surface until a
  replacement, detach, or destroy commit has been issued.
- Cursor surfaces and drag icon surfaces have explicit surface-runtime roles and
  are destroyed through role-specific owners.
- `CursorManager.shutdown()` is an explicit display-session teardown step. It
  detaches and commits cursor surfaces before destroying them so theme-owned and
  custom SHM buffers are no longer attached when cursor resources are released.
- Fatal display cleanup swaps the live surface graph to an empty store before
  releasing the discarded graph, and the discard flag suppresses window and popup
  lifecycle callbacks while that release is in progress.
- Drag icon pixels are validated against the declared XRGB8888 image size before
  SHM storage is filled.
- Drag icon surfaces are destroyed on source cancellation, source completion,
  failed drag start, and display teardown.

Tests:

- `CursorManagerTests` covers cursor-shape selection, cursor surface creation,
  theme fallback, custom image attachment, cursor surface destruction requests,
  and idempotent shutdown ordering.
- `CursorScalePolicyTests` and `CursorAnimationStateTests` cover internal cursor
  scale and animation state models.
- `DataTransferManagerDragSourceTests` covers drag icon preparation and source
  lifecycle cleanup.
- `DisplayEventHubPopupTests` and `DisplayCoreInvariantTests` cover fatal
  cleanup callback suppression and repeated close/fail cleanup calls.

## Scale Extension Raw Boundary

Remaining unsafe constructs:

- `RawDisplayConnection+OptionalGlobals` binds optional `wp_viewporter` and
  `wp_fractional_scale_manager_v1` globals through registry C shims.
- `RawViewporter`, `RawViewport`, `RawFractionalScaleManager`, and
  `RawFractionalScale` wrap extension proxies returned by those shims.
- `RawXDGActivation` wraps the optional `xdg_activation_v1` manager and
  `RawXDGActivationToken` wraps async token request objects. Both destroy their
  proxies through explicit C shims, and token listeners use `CListenerStorage`.
- `RawSurfaceScaleOwner` and `RawFractionalScaleOwner` store C listener
  callback tables through `CListenerStorage`.
- Listener callbacks recover Swift owners from C `data` pointers and forward
  preferred integer or fractional scale values.

Audit invariant:

- Optional scale globals are bound only after registry discovery advertises
  them.
- Scale extension proxies are adopted through `RawProxyAdoptionContext`, then
  destroyed through `RawOwnedProxy`.
- A failed adoption destroys the just-created raw proxy before throwing.
- Listener storage is invalidated before scale extension objects are destroyed
  during window teardown.
- Fractional scale is used by `WaylandClient` only when both
  `wp_fractional_scale_manager_v1` and `wp_viewporter` are available.

Tests:

- `SurfaceGeometryTests` covers scale arithmetic, invalid preferred scale
  values, and the integer-to-fractional scale state transition.
- `VersionNegotiationTests` covers supported protocol versions for the scale
  globals.

## Surface Region Boundary

Remaining unsafe constructs:

- `RawRegion` wraps compositor-created `wl_region` proxies.
- `RawSurface` passes region proxies to `wl_surface.set_input_region` and
  `wl_surface.set_opaque_region`.

Audit invariant:

- Public API accepts only logical `SurfaceRegion` and `SurfaceDamageRegion`
  values, raw `wl_region` objects are not public.
- One-shot region application creates a raw region, adds its rectangles, sends
  the surface request, and destroys the region before returning.
- `nil` input or opaque region sends a null region pointer to reset compositor
  defaults.
- Damage rectangles are nonempty, map from logical coordinates through current
  surface geometry, clip partial overhang to surface bounds, and reject
  rectangles with no surface intersection.

Tests:

- `RawSurfaceRegionRequestTests` covers raw region creation, add, subtract,
  surface input/opaque region requests, null resets, and destroy ordering.
- `SurfaceGeometryTests` covers logical-to-buffer damage mapping, fractional
  scale rounding, clipped partial damage, and rejected non-intersecting damage.
- `SurfaceRuntimeSubmitTests` covers commit ordering for explicit logical
  damage when buffer damage is unavailable.

## Data Transfer File Descriptors

Remaining unsafe constructs:

- `RawFileDescriptor` owns POSIX descriptors returned by pipe creation and raw
  Wayland data-transfer callbacks.
- `OwnedFileDescriptor` exposes a public, noncopyable read handle for offer
  payloads.
- `DataTransferPipeDescriptors` models the read/write pipe pair used for
  receive requests.
- `DataTransferSourceSendRequest` stores one raw descriptor slot for compositor
  send requests.
- `ThreadedDataTransferSourceWriter` writes local payload bytes to compositor
  pipes on a worker thread.

Audit invariant:

- A descriptor is either owned by one Swift wrapper, transferred exactly once to
  a Wayland request, or closed exactly once.
- Receive-pipe write ends are transferred only after read-end adoption succeeds.
- Rejected receive requests close both pipe ends that remain locally owned.
- Source send descriptors are released from their mutex-backed slot at most
  once, then closed by the write job or cancellation path.
- Public `OwnedFileDescriptor.readData` bounds the read size and uses a timeout
  so a compositor-provided pipe cannot force unbounded memory growth or an
  indefinite public API call.

Tests:

- `DataTransferPipeDescriptorTests` covers pipe descriptor value behavior.
- `DataTransferPipeReceiveTests` covers read-end adoption, write-end transfer,
  receive failure, and descriptor close paths.
- `ClipboardOfferReadTests` and `DataTransferReadableOfferTests` cover bounded
  public reads.
- `DataTransferSourceWriteJobLifecycleTests`,
  `DataTransferSourceWriteJobCloseResultTests`,
  `DataTransferSourceWriterShutdownTests`, and
  `DataTransferSourceWriterSourceCancellationTests` cover source-side write
  job descriptor release and cancellation behavior.

## linux-dmabuf Boundary

Remaining unsafe constructs:

- `RawLinuxDmabufFeedback` accumulates compositor feedback events into typed
  snapshots.
- `RawLinuxDmabufFormatTable` maps compositor-provided format-table file
  descriptors.
- `RawLinuxDmabufBufferParams` sends plane descriptors and creates dmabuf
  buffers.
- `RawLinuxDmabuf` and `RawLinuxDmabufBuffer` are `@unchecked Sendable` so the
  package-internal managed GPU preview path can borrow the display-owned
  dmabuf manager and move an imported buffer into presenter lifetime tracking.
- `RawLinuxDmabufPlaneFileDescriptor` owns a plane descriptor before it is
  transferred to `zwp_linux_buffer_params_v1.add`.
- `WaylandGraphicsExternalBufferDescriptor` and
  `WaylandGraphicsExternalBufferPlane` are public preview move-only values.
  Their manufacturing path consumes an `OwnedFileDescriptor`, offset, and
  stride, then stores the descriptor package-internally for transfer into the
  dmabuf import path. Callers can describe one-plane renderer-owned images
  without receiving reusable file-descriptor access, raw Wayland proxies,
  GBM/EGL/DRM objects, syncobj handles, or pointers.
- `WaylandGraphicsExternalBufferSubmissionReceipt` retains a private actor
  release state. The receipt may be awaited repeatedly, and all waiters resolve
  to the same terminal release result. The release registry is package-private,
  protected by `NSLock`, and maps presenter slots to submission identities only
  while a submitted buffer awaits release.
- `RawSurfaceBuffer` is `@unchecked Sendable` because the managed GPU preview
  presenter passes an imported `wl_buffer` wrapper through the async
  owner-thread commit bridge without exposing the proxy to public API.
- linux-dmabuf listener callbacks recover Swift owners from C listener `data`
  pointers.

Audit invariant:

- Feedback batches are atomic. A new batch must not merge stale tranche data
  with newly received compositor events.
- Exact-one feedback events reject duplicates before producing
  `RawLinuxDmabufFeedbackSnapshot`.
- Format-table byte count, descriptor validity, and descriptor size are
  validated before reading mapped bytes, so a short fd cannot become a SIGBUS
  process termination.
- Buffer params reject empty, duplicate, non-zero-starting, and gapped plane
  sets before sending `create`.
- Version-gated feedback requests require a bound linux-dmabuf object that
  supports protocol version 4.
- Plane descriptors are released only for the `add` request path, rejected
  planes remain locally owned and are closed by their wrapper.
- External buffer descriptors validate positive size, nonzero DRM format,
  positive stride, consecutive plane indices, and single ownership before any
  import request. Public one-plane descriptors use plane index 0. Import-plan
  deinitialization closes any plane descriptor that was not transferred to
  Wayland.
- External submission receipts are completed only by implicit compositor buffer
  release, backing close, or a terminal submission failure. A successful commit,
  presentation feedback event, timeout, or later submission does not make a
  renderer-owned image reusable.
- The display-owned linux-dmabuf manager is accessed only through package-only
  `Window`/`WaylandDisplay` helpers that execute on the display owner thread.
- Imported dmabuf buffers are destroyed by the GPU presenter buffer wrapper and
  are retained until compositor release or explicit backing retirement.

Tests:

- `RawLinuxDmabufFeedbackTests` covers complete feedback batches, malformed
  ordering, duplicate exact-one events, duplicate formats, and stale-batch
  replacement.
- `RawLinuxDmabufFormatTableTests` covers byte count validation, short fd
  rejection, descriptor closure, and system mapping failures.
- `RawLinuxDmabufBufferParamsTests` covers lifecycle state, descriptor
  transfer, duplicate plane index rejection, empty plane rejection, and
  consecutive plane-set validation.
- `LinuxDmabufShimContractTests` covers request wrapper targets, dimensions,
  flags, modifier splitting, and feedback request targets.
- `WaylandGraphicsExternalBufferSubmissionTests` covers descriptor validation,
  ownership transfer into an import plan, unavailable/fallback preflight before
  Wayland import, public release receipt completion, and backing-close waiter
  resolution.

## Surface Submit Constraint Boundary

Remaining unsafe constructs:

- `RawDrmSyncobjTimelineFD` owns a DRM syncobj timeline fd before it is
  transferred to `wp_linux_drm_syncobj_manager_v1.import_timeline`.
- `RawLinuxDrmSyncobjManager`, `RawLinuxDrmSyncobjSurface`, and
  `RawLinuxDrmSyncobjTimeline` own protocol proxies through `RawOwnedProxy`.
- `RawFifoManager`, `RawFifo`, `RawCommitTimingManager`, and `RawCommitTimer`
  own staging protocol objects for surface submit constraints.
- CWaylandProtocols request shims forward syncobj, FIFO, and commit-timing
  requests and expose test recording only in explicit testing builds.

Audit invariant:

- Timeline fds reject negative descriptors before ownership starts.
- A timeline fd transfers at most once. Rejected descriptors close through the
  fd wrapper, imported descriptors close after the Wayland request has copied
  the fd into the protocol call, including both successful and failed
  `import_timeline` requests.
- Syncobj surface, FIFO, and commit-timer objects are locally limited to one
  object per `wl_surface`.
- Explicit submit constraints are validated before surface commit effects:
  release points are required for buffer commits, acquire/release points are
  rejected without an attached buffer, and same-timeline acquire points must be
  earlier than release points.
- Commit-timing timestamps reject nanosecond values outside the POSIX timespec
  range before crossing the C boundary.

Tests:

- `RawSubmitConstraintTests` covers syncobj timeline point splitting, timeline
  fd validation, release semantics, deinit close behavior, import success and
  failure close behavior, and commit-timing timestamp validation.
- `SubmitConstraintShimContractTests` covers C request wrapper targets,
  argument ordering, point splitting, timestamp splitting, and destroy targets.
- `SurfaceSubmitConstraintsTests` covers implicit defaults, explicit
  synchronization validation, FIFO and commit-timing capability checks, and
  timestamp validation.

## Surface Metadata Boundary

Remaining unsafe constructs:

- `RawContentTypeManager`, `RawAlphaModifierManager`,
  `RawTearingControlManager`, `RawColorRepresentationManager`, and
  `RawColorManager` own staging protocol manager proxies through
  `RawOwnedProxy`.
- Per-surface metadata wrappers own the corresponding content type, alpha,
  tearing-control, color-representation, and color-management proxy objects.
- `RawImageDescription` and `RawImageDescriptionReference` own immutable
  color-management image-description proxies.
- CWaylandProtocols metadata shims forward generated protocol requests for
  metadata object creation, metadata setters, image-description retrieval, and
  destroy requests.

Audit invariant:

- Metadata manager wrappers locally reject duplicate per-surface or per-output
  object creation before the compositor can raise protocol errors.
- Surface metadata objects are destroyed with the `SurfaceRuntime` surface
  object set and capabilities are reset on surface destruction.
- Unknown raw content, alpha, presentation, color-representation, and
  render-intent values are preserved at the raw/value boundary.
- `SurfaceCommitMetadata.default` does not create optional protocol objects or
  change existing SHM/GPU commit behavior.
- Color-representation support is not published as final capability state until
  the compositor's support-list `done` event is observed.
- Image descriptions are not usable as commit metadata until their ready event
  publishes a nonzero identity. Pending, failed, malformed, or mismatched
  image-description objects are rejected before metadata requests are emitted.
- Metadata application preflights object availability and color-description
  identity before sending double-buffered Wayland state requests, so failed
  metadata commits do not dirty later commits.

Tests:

- `RawSurfaceMetadataTests` covers protocol raw values, unknown-value
  preservation, boundary alpha multiplier values, and idempotent metadata/image
  description destruction.
- `SurfaceCommitMetadataTests` covers default behavior, unavailable capability
  errors, available capability validation, capability snapshot publication, and
  unknown-value preservation.
- `SurfaceColorMetadataReadinessTests` and
  `SurfaceCommitColorDescriptionTests` cover color-representation support
  readiness and image-description pending/ready/failed states.

## GBM and DRM Boundary

Remaining unsafe constructs:

- `GBMRenderNodeFileDescriptor` owns a DRM render-node fd before it is adopted
  by `GBMDevice`.
- `GBMDevice` owns the `gbm_device` pointer and the adopted render-node fd.
- `GBMBuffer`, `GBMSurface`, and `GBMLockedSurfaceBuffer` wrap GBM pointers with
  explicit live-pointer checks.
- `GBMDmabufExport` owns exported plane fds until each plane descriptor is
  transferred or the export object is destroyed. It is `@unchecked Sendable`
  only for the package-internal setup handoff from GBM export to Wayland dmabuf
  import.
- CGBM shims call libgbm/libdrm functions and expose test-recording hooks only
  in explicit testing builds.

Audit invariant:

- Render-node fds are preferred for unprivileged clients. Primary-node fallback
  is not used without a DRM-authentication model.
- The render-node fd adopted by GBM is closed after `gbm_device_destroy`.
- `DRM_FORMAT_MOD_INVALID` uses implicit GBM allocation, while explicit
  modifier allocation masks `GBM_BO_USE_LINEAR` before calling Mesa's
  modifier-aware API.
- Borrowed plane layout does not expose an owned-looking raw fd.
- Exported plane fds are transferred only through
  `GBMDmabufExport.takePlaneFileDescriptor(at:)`, untaken fds close during
  export destruction.
- Locked GBM surface buffers cannot be exported or released after their surface
  has been destroyed.
- Managed GPU preview keeps the locked front buffer alive behind the imported
  Wayland buffer and releases it only after `wl_buffer.release`, backing close,
  or presenter retirement. Buffer slots are not made available for reuse before
  the release path records completion.

Tests:

- `DRMRenderNodeSelectionTests` covers DRM device-byte validation and render-node
  selection behavior.
- `GBMDeviceTests` covers fd adoption, invalid descriptor rejection, device
  destruction, and allocation policy.
- `GBMDmabufExportTests` covers plane layout, descriptor transfer, second-take
  rejection, and close behavior for taken and untaken plane descriptors.
- `GBMSurfaceTests` covers front-buffer lease behavior and destroyed-surface
  errors.
- `GBMShimTests` covers C shim null-input and allocation recording behavior.

## EGL Rendering Boundary

Remaining unsafe constructs:

- `EGLGBMRenderTarget` owns an EGL display, config, context, surface, and its
  backing `GBMSurface`.
- EGL C shims make and clear current context state for deterministic test draws.
- `EGLClientExtensions` parses client extension strings from EGL.

Audit invariant:

- EGL display/context/surface handles are created as one live-handle set and
  destroyed at most once.
- `drawClear` enters the context through a scoped make-current path and reports
  clear-current failure instead of returning success with a still-current
  context.
- GBM platform support is detected from the parsed EGL client extension set.
- Render-target destruction marks live GBM surface-buffer leases terminal before
  destroying the backing surface.

Tests:

- `EGLRenderTargetTests` covers extension parsing, live target creation when
  GBM/EGL are available, clear-current failure propagation, and destroyed-target
  behavior.
- `EGLShimTests` covers EGL shim failure paths and test-mode recording.

## GPU Preview Boundary

Remaining unsafe constructs:

- `GPUDmabufBufferImport` owns a one-shot dmabuf params create request and its
  callback box.
- `GPUDmabufBufferImporter` transfers GBM-exported plane descriptors into
  linux-dmabuf params.
- `GPUWindowPresenter` tracks installed `wl_buffer` objects, GBM buffer-pool
  slots, and Wayland release callbacks.
- `RawLinuxDmabufBuffer` wraps imported `wl_buffer` proxies and reports release
  callbacks.

Audit invariant:

- A dmabuf import request starts in `createRequested`, accepts compositor
  created/failed events only in that state, and reports terminal-state events
  through the failure callback.
- Plane descriptors are added before `create`, add/create failures destroy the
  params object and close any plane descriptor that remains locally owned.
- GPU presentation uses the window's surface transaction generation authority.
  software and GPU commits do not allocate independent generation sequences.
- Submitted GPU buffer-pool slots return to availability only after the matching
  Wayland buffer release.
- Raw GPU preview plumbing remains package-internal. The public graphics preview
  contract exposes renderer-neutral capabilities plus move-only external-buffer
  descriptor and release-receipt values.
- `GPUWindowBackingState` is the internal state snapshot for lifecycle,
  runtime-path facts, buffer-pool readiness, last submitted frame, diagnostics,
  fallback, and failure.
- Preview diagnostics remain package-internal typed payloads. The public
  `WaylandGraphicsPreview` product exposes only renderer-neutral capability,
  runtime-path, fallback, and unavailable values.

Tests:

- `GPUDmabufBufferImporterTests` covers import descriptor validation, plane
  export transfer, compositor import failure, destroy-before-late-callback
  behavior, terminal-state events, and import request lifecycle.
- `GPUWindowPresenterStateTests` covers install, lease, submit, release,
  committed-untracked release/reuse, failed runtime-path projection, and
  release-failure state transitions.
- `WaylandGraphicsPreviewAPITests` and
  `IntegrationTests/GraphicsPreviewClient` cover the public preview value
  boundary without exposing raw unsafe handles.
- `WindowModelExternalPresentationTests` and `SurfaceTransactionStateTests`
  cover shared commit-generation rules used by software and GPU presentation.
