# Roadmap

WaylandClientKit is pre-foundation. The roadmap is intentionally short: stabilize
the public substrate, keep preview graphics honest, and avoid promising support
before the repo has evidence.

## Current Focus

- Keep `WaylandClient` API changes audited and documented.
- Keep `WaylandGraphicsPreview` clearly marked as source-breaking preview API.
- Broaden compositor evidence for KDE/KWin, GNOME/Mutter, wlroots, and Weston.
- Keep raw Wayland, GBM, EGL, DRM, dmabuf, syncobj, file descriptor, and unsafe
  implementation handles internal.
- Keep generated protocol artifacts reproducible from vendored XML.

## Before A Foundation Candidate

- `swift run wck ci release` passes from a clean checkout.
- `swift run wck api verify` and `swift run wck docs verify` pass.
- The compositor matrix has current active/fallback evidence for core desktop
  paths.
- Public API docs describe supported behavior without relying on implementation
  notes.
- Known source-breaking preview areas are documented in `docs/versioning.md`.

## Later

- Broader graphics-preview evidence across compositors.
- More output/color-management evidence.
- More text-input and input-method coverage.
- Regular `0.x` release tags after compatibility checks pass.
