# Strict Memory Safety Audit

SwiftWayland treats raw Wayland objects and shared-memory mappings as explicit unsafe islands. Public client-facing APIs should not expose raw C pointers or mmap lifetimes directly.

## Shared Memory and Borrowed Buffers

Remaining unsafe constructs:

- `RawBorrowedBuffer` stores a borrowed `wl_buffer` pointer returned by cursor theme APIs.
- `RawBuffer` stores an `UnsafeMutableRawBufferPointer` into an mmap-backed SHM pool.
- `MappedRegion` owns the mmap base address and unmaps it in `deinit`.
- `RawSurface` passes owned or borrowed buffers to `wl_surface.attach`.

Audit invariant:

- A `RawSharedMemoryPool` owns its mmap for at least as long as any `RawBuffer` created from that mapping.
- `RawBuffer.withUnsafeMutableBytes` is the only normal way for client code to borrow buffer memory.
- `SoftwareFrame` validates dimensions, stride, and byte count before exposing row spans to redraw code.
- Borrowed cursor buffers are never written by SwiftWayland. They are only attached to cursor surfaces.

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
- Seat, pointer, keyboard, touch, data-device, XDG, buffer-release, frame
  callback, scale-extension, cursor-shape, and text-input listeners recover
  Swift owners from C callback payloads.
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

## Cursor And Drag Visual Surfaces

Remaining unsafe constructs:

- `RawCursorShapeManager` and `RawCursorShapeDevice` wrap compositor-managed
  cursor-shape protocol objects.
- `CursorRoleSurface` owns a `wl_surface` used as the pointer cursor image
  surface and routes commits through `SurfaceRuntime`.
- `DragIconRoleSurface` owns a `wl_surface` and SHM buffer used as a source-side
  drag icon surface.

Audit invariant:

- Cursor-shape device listeners and raw proxies are destroyed with the cursor
  manager backend.
- A cursor request uses compositor cursor-shape only when the requested
  `PointerCursor` maps to a known protocol shape; otherwise the theme-surface
  path remains the fallback.
- Cursor surfaces and drag icon surfaces have explicit surface-runtime roles and
  are destroyed through role-specific owners.
- Drag icon pixels are validated against the declared XRGB8888 image size before
  SHM storage is filled.
- Drag icon surfaces are destroyed on source cancellation, source completion,
  failed drag start, and display teardown.

Tests:

- `CursorManagerTests` covers cursor-shape selection, cursor surface creation,
  theme fallback, and cursor surface destruction requests.
- `CursorScalePolicyTests` and `CursorAnimationStateTests` cover internal cursor
  scale and animation state models.
- `DataTransferManagerDragSourceTests` covers drag icon preparation and source
  lifecycle cleanup.

## Scale Extension Raw Boundary

Remaining unsafe constructs:

- `RawDisplayConnection+OptionalGlobals` binds optional `wp_viewporter` and
  `wp_fractional_scale_manager_v1` globals through registry C shims.
- `RawViewporter`, `RawViewport`, `RawFractionalScaleManager`, and
  `RawFractionalScale` wrap extension proxies returned by those shims.
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
- `RawLinuxDmabufPlaneFileDescriptor` owns a plane descriptor before it is
  transferred to `zwp_linux_buffer_params_v1.add`.
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
- Plane descriptors are released only for the `add` request path; rejected
  planes remain locally owned and are closed by their wrapper.

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

## GBM and DRM Boundary

Remaining unsafe constructs:

- `GBMRenderNodeFileDescriptor` owns a DRM render-node fd before it is adopted
  by `GBMDevice`.
- `GBMDevice` owns the `gbm_device` pointer and the adopted render-node fd.
- `GBMBuffer`, `GBMSurface`, and `GBMLockedSurfaceBuffer` wrap GBM pointers with
  explicit live-pointer checks.
- `GBMDmabufExport` owns exported plane fds until each plane descriptor is
  transferred or the export object is destroyed.
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
  `GBMDmabufExport.takePlaneFileDescriptor(at:)`; untaken fds close during
  export destruction.
- Locked GBM surface buffers cannot be exported or released after their surface
  has been destroyed.

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
- Plane descriptors are added before `create`; add/create failures destroy the
  params object and close any plane descriptor that remains locally owned.
- GPU presentation uses the window's surface transaction generation authority;
  software and GPU commits do not allocate independent generation sequences.
- Submitted GPU buffer-pool slots return to availability only after the matching
  Wayland buffer release.
- GPU preview APIs remain package-internal until the public graphics contract
  has surface capability, color metadata, and synchronization requirements.

Tests:

- `GPUDmabufBufferImporterTests` covers import descriptor validation, plane
  export transfer, terminal-state events, and import request lifecycle.
- `GPUWindowPresenterStateTests` covers install, lease, submit, release, and
  release-failure state transitions.
- `WindowModelExternalPresentationTests` and `SurfaceTransactionStateTests`
  cover shared commit-generation rules used by software and GPU presentation.
