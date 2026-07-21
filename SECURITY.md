# Security Policy

## Supported Versions

WaylandClientKit is pre-foundation and does not yet publish stable release
branches. Reports apply to `main` unless a release branch is documented.

## Reporting a Vulnerability

Private reports are welcome through GitHub vulnerability reporting or
<wck.197t1@simplelogin.fr>. This gives the project time to investigate before
details are public.

Include:

- affected commit or version
- operating system and compositor, if relevant
- reproduction steps
- whether the issue involves memory safety, file descriptor ownership, protocol
  object lifecycle, or generated C shims
- any sanitizer output

## Scope

Security-relevant areas include:

- raw Wayland protocol wrappers
- C shims
- file descriptor ownership
- dmabuf, GBM, and EGL preview paths
- data-transfer payload handling
- event stream lifecycle and overflow
- unsafe or unchecked `Sendable` regions

Private reports with clear reproduction steps are preferred. Public vulnerability
reports may put users at risk before a fix is available.
