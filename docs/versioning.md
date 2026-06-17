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

## First Public Tag

The first public tag should be `0.1.0` after public-readiness checks pass.

Use `0.1.0-preview.1` only if the repository is public but the maintainer wants
one more explicitly pre-release checkpoint before a normal `0.1.0` tag.

Do not use `1.0.0` until the foundation contract is documented, tested, and
supported by release evidence.
