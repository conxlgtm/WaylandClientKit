# Versioning

WaylandClientKit uses SemVer-shaped tags, but it is pre-foundation.

## Current Policy

- `0.x` releases may include source-breaking changes.
- `WaylandClient` public API is audited and baseline tracked, but not frozen.
- `WaylandGraphicsPreview` is source-breaking preview API.
- Protocol additions may add public API when the protocol is surfaced above raw
  wrappers.
- Breaking public changes require updates to the public API baseline and audit.
- Public docs should explain new user-facing behavior before release notes claim
  it.

## Public Tags

The first public tag is `0.1.0`.

`1.0.0` begins when the foundation contract is documented, tested, and backed
by release evidence.
