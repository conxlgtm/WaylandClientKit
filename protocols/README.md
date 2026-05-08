# Wayland Protocol Inputs

This directory contains vendored Wayland protocol XML used to generate the checked-in C protocol artifacts under `Sources/CWaylandProtocols/`.

- `manifest.json` records the upstream source and checksum for each vendored protocol.
- `upstream/` contains copied upstream XML without local edits.
- `patches/` is reserved for explicit local protocol patches if one is ever needed.

Run `./scripts/protocols/generate.sh` after changing XML inputs.
