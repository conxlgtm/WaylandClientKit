# Manual Testing

Manual compositor checks should use the repository Swift wrapper so the runtime
library path matches the local build environment. Direct `swift run` commands
need equivalent runtime library configuration.

Record live compositor facts in `docs/compositor-matrix.md`. Keep unit-test
results separate from compositor evidence.

## Baseline

Run the noninteractive checks first:

```bash
./scripts/smoke/collect-compositor-facts.sh
make smoke-wayland
make integration-wayland
make gpu-preview-wayland
```

For headless Weston:

```bash
make wayland-headless
make gpu-preview-headless
```

## Framework-Facing Examples

Run the manual interaction probes:

```bash
./scripts/dev/swift.sh run ClientSideResizeChrome
./scripts/dev/swift.sh run SerialActionsProbe
./scripts/dev/swift.sh run XDGActivationSmoke
```

Run bounded examples when a compositor session is available:

```bash
./scripts/dev/swift.sh run TwoWindowFrameworkHost -- --auto-close --print-summary
./scripts/dev/swift.sh run TwoWindowOrderStress -- --duration-seconds 3 --print-summary
./scripts/dev/swift.sh run TextInputSmoke -- --auto-close --print-summary
./scripts/dev/swift.sh run DataTransferSmoke -- --auto-close --print-summary
./scripts/dev/swift.sh run PresentationFeedbackAnimation -- --duration-seconds 3 --print-summary
./scripts/dev/swift.sh run GPUPreviewSmokeClient
```

## Notes To Capture

- compositor name and version
- advertised optional protocols
- client-side resize and cursor cleanup result
- serial-sensitive resize, move, menu, and drag-source result
- text-input capability, IME commits, and interpreted keyboard fallback
- clipboard, primary-selection, drag/drop, private MIME, and stale-offer behavior
- popup lifecycle and shutdown behavior
- presentation feedback and graphics-preview fallback behavior
