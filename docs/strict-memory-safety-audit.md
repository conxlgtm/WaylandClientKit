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
- Borrowed cursor buffers are never written by SwiftWayland; they are only attached to cursor surfaces.

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
