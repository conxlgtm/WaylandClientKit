# Compositor Session Management Plan

WaylandClientKit tracks compositor session-management support through the
upstream staging protocol `xdg-session-management-v1`.

## Protocol Decision

- XML name: `xdg-session-management-v1.xml`
- Primary global: `xdg_session_manager_v1`
- Upstream phase: staging
- Vendored source: wayland-protocols 1.48 staging
- Current product tier: preview foundation

The protocol is vendored and generated, and raw wrappers exist for package
experiments. The public API intentionally exposes only
`WaylandCapabilities.compositorSessionManagement` for now.

## Boundary

WaylandClientKit can expose compositor facts and protocol-shaped requests. It
does not own framework scene identity, document identity, restore schemas,
state migration, or user-facing save/restore policy.

Local framework restoration remains based on app-owned state plus
`WindowRestorationSnapshot`. `SessionStateSmoke` remains the runnable local
restoration example.

## Deferred Public API

A broader public compositor session API needs more evidence before release:

- live compositor advertisement rows in `docs/compositor-matrix.md`
- lifecycle smoke output for created/restored/replaced events
- clear behavior across display close, window close, and late compositor events
- a framework usage shape that keeps compositor session identities separate
  from local scene/document keys

Until those are proven, `CompositorSessionSmoke` reports capability and skips
public session binding.

## Text Input 1.48 Refresh

The bundled `text-input-v3` XML is the v2 protocol shape. Public text-input
support includes preedit hints, language events, on-screen input content hints,
and version-gated input-panel show/hide hints. `disable()` still finalizes the
disable request and should not be followed by `commit()`.
