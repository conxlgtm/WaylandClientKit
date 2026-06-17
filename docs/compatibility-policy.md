# Compatibility Policy

WaylandClientKit is pre-foundation. That means public API can still change, but
changes must be deliberate, reviewed, documented, and covered by the public API
baseline.

WaylandClientKit is distributed under the repository [Apache License 2.0](../LICENSE).
The license grants reuse rights. This policy describes API compatibility and
review expectations.

## Compatibility Tiers

| Tier | Promise | Breaking change process | Required checks |
| --- | --- | --- | --- |
| `WaylandClient` public API | Main public app-substrate product. Source changes are allowed before foundation, but must be intentional. | Update public API baseline, public API audit, DocC/user docs, tests, and release notes when user-visible. | `swift run wck api verify`, `swift run wck docc verify`, public integration client. |
| `WaylandGraphicsPreview` public API | Source-breaking preview product. Preview drift is allowed, but not invisible. | Update baseline/audit/docs/tests. Say why preview source breakage is acceptable. Keep raw handles internal. | `swift run wck api verify`, graphics preview integration client, examples build. |
| Executable products and examples | Examples may change, but should remain runnable, useful, and matrix-friendly. | Update docs and example checklist when adding, renaming, or changing expected output. | `swift run wck examples build`, relevant smoke command. |
| Package-internal targets | May change without source compatibility promises. Resource, unsafe, and owner-thread invariants must stay tested. | Update strict memory-safety audit when unsafe or unchecked sendability changes. Add tests for lifetime/resource rules. | unsafe allowlist, focused unit tests, strict concurrency build. |
| Generated/raw protocol wrappers | Not user-facing product API. Generated shape follows vendored protocol XML and shim contracts. | Regenerate with `wck`, update manifests/checksums, and verify shims. | protocol generation verification, shim verification. |
| Tooling commands | Contributor command behavior should be stable enough for docs and CI. | Update `docs/tooling.md`, release docs, CI/plugin/just wrappers, and tests when command names or behavior change. | `swift run wck ci check`, tool tests. |

## Baseline And Audit Rules

- Public API changes in vended products require `docs/public-api-baseline.md`
  and `docs/public-api-audit.md` to agree.
- Preview API changes are still baseline tracked. Do not bypass review because
  a product is preview.
- Public `WaylandClient` must not expose raw Wayland, GBM, EGL, DRM, dmabuf,
  syncobj, file descriptor, or unsafe implementation handles.
- `WaylandGraphicsPreview` must remain renderer-neutral and raw-handle-free.
- Public docs must explain new public behavior before release notes claim it.
- Restoration and session-readiness APIs are platform facts. They must not
  promise scene, document, or compositor session-management policy.

## External Client Rules

External integration packages are proof that public users do not need internal
targets. When a public product changes:

- `WaylandClient` changes should keep the public API client compiling or update
  the expected baseline intentionally.
- `WaylandGraphicsPreview` changes should keep the graphics preview client
  hardware-independent unless the change explicitly targets live-gated GPU
  evidence.

## Release Note Rules

Release or checkpoint notes should mention:

- New public API families.
- Source-breaking changes in either public product.
- New or removed example commands.
- New required system dependencies.
- Runtime evidence changes for managed GPU preview.
