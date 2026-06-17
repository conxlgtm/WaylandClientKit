# Wayland Protocol Inputs

This directory contains vendored Wayland protocol XML used to generate the checked-in C protocol artifacts under `Sources/CWaylandProtocols/`.

- `manifest.json` records upstream source resolution, generated paths, scanner
  modes, checksums, WaylandClientKit tier, API exposure, and test strategy for each
  vendored protocol.
- `upstream/` contains copied upstream XML without local edits.
- `patches/` is reserved for explicit local protocol patches if one is ever needed.

Run `swift run wck protocols generate` after changing XML inputs. Run
`swift run wck protocols verify-manifest` after changing manifest metadata. It
validates path containment and the recorded XML checksums.
