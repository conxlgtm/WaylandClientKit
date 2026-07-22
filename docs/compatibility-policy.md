# Compatibility Policy

WaylandClientKit is pre-foundation. Public API can still change. Each change is
reviewed, documented, and recorded in the public API baseline.

WaylandClientKit is distributed under the repository [Apache License 2.0](../LICENSE).
The license grants reuse rights. This policy describes API compatibility and
review expectations.

## Compatibility Tiers

| Tier | Promise | Breaking change process | Required checks |
| --- | --- | --- | --- |
| `WaylandClient` public API | Main public app-substrate product. Source changes are allowed before foundation. | Update public API baseline, public API audit, DocC/user docs, tests, and release notes when user-visible. | `swift run wck api verify`, `swift run wck docc verify`, public integration client. |
| `WaylandGraphicsPreview` public API | Source-breaking preview product. | Update baseline, audit, docs, and tests. Explain source breakage. Keep raw Wayland/GBM/EGL objects internal. Narrow move-only values may consume file descriptors when ownership is documented and audited. | `swift run wck api verify`, graphics preview integration client, examples build. |
| Executable products and examples | Examples may change while remaining runnable and useful for compositor evidence. | Update docs and the example checklist when commands or output change. | `swift run wck examples build`, relevant smoke command. |
| Package-internal targets | No source compatibility promise. Resource, unsafe, and owner-thread invariants remain tested. | Update the strict memory-safety audit for unsafe or unchecked-sendability changes. Test lifetime and resource rules. | unsafe allowlist, focused unit tests, strict concurrency build. |
| Generated/raw protocol wrappers | Not user-facing product API. Generated shape follows vendored protocol XML and shim contracts. | Regenerate with `wck`, update manifests/checksums, and verify shims. | protocol generation verification, shim verification. |
| Tooling commands | Contributor command behavior should be stable enough for docs and CI. | Update `docs/tooling.md`, release docs, CI/plugin/just wrappers, and tests when command names or behavior change. | `swift run wck ci check`, tool tests. |

## Baseline And Audit Rules

- Public API changes in vended products require `docs/public-api-baseline.md`
  and `docs/public-api-audit.md` to agree.
- The public API baseline is generated from compiler symbol graphs. It tracks
  public signatures, availability, generic constraints, and relationships, but
  deliberately ignores source locations and formatting.
- Preview API remains baseline tracked.
- Public `WaylandClient` excludes raw Wayland, GBM, EGL, DRM, dmabuf,
  syncobj, borrowed file descriptor integers, reusable descriptor accessors,
  or unsafe implementation handles. A narrow ownership-transfer value may
  adopt or release an owned descriptor when its consuming and close behavior
  is documented, without providing reusable borrowed access.
- `WaylandGraphicsPreview` remains renderer-neutral. It may expose narrow,
  move-only, consuming graphics interop values backed by dma-buf or DRM syncobj
  file descriptors. These values exclude raw Wayland objects, pointers,
  GBM/EGL objects, DRM object handles, or reusable borrowed descriptor access.
  Ownership transfer, close behavior, and asynchronous lifetime are documented
  and audited.
- Public docs explain new behavior before release notes claim it.
- Restoration and session-readiness APIs report platform facts, not scene,
  document, or compositor session-management policy.

## External Client Rules

External integration packages are proof that public users do not need internal
targets. When a public product changes:

- A `WaylandClient` change either keeps the public client compiling or updates
  its expected baseline.
- The graphics preview client stays hardware-independent except for changes
  that explicitly target live GPU evidence.

## Release Note Rules

Release or checkpoint notes should mention:

- New public API families.
- Source-breaking changes in either public product.
- New or removed example commands.
- New required system dependencies.
- Runtime evidence changes for managed GPU preview.
