# Manual Testing

Manual compositor checks should use `swift run` from the repository root or
`nix develop -c swift run ...` when using the Nix development shell.

Record live compositor facts in `docs/compositor-matrix.md`. Keep unit-test
results separate from compositor evidence.

## Baseline

Run the noninteractive checks first:

```bash
swift run swl smoke live
swift run swl smoke integration
swift run swl smoke gpu-preview
```

For headless Weston:

```bash
swift run swl smoke headless -- swl smoke integration
swift run swl smoke headless -- swl smoke gpu-preview
```

## Framework-Facing Examples

Run the manual interaction probes:

```bash
swift run ClientSideResizeChrome
swift run SerialActionsProbe
swift run XDGActivationSmoke
swift run PointerCaptureSmoke
swift run CursorPolicySmoke
```

Run bounded examples when a compositor session is available:

```bash
swift run TwoWindowFrameworkHost -- --auto-close --print-summary
swift run TwoWindowOrderStress -- --duration-seconds 3 --print-summary
swift run TextInputSmoke -- --auto-close --print-summary
swift run DataTransferSmoke -- --auto-close --print-summary
swift run PresentationFeedbackAnimation -- --duration-seconds 3 --print-summary
swift run GPUPreviewSmokeClient
swift run GraphicsPreviewManagedGPUClear
```

## Notes To Capture

- compositor name and version
- advertised optional protocols
- client-side resize and cursor cleanup result
- serial-sensitive resize, move, menu, and drag-source result
- xdg activation capability, token request result, and activate request result
- relative pointer and pointer lock/confine capability and request result
- cursor shape, theme fallback, focused-output scale policy, and close result
- text-input capability, IME commits, and interpreted keyboard fallback
- clipboard, primary-selection, drag/drop, private MIME, and stale-offer behavior
- popup lifecycle and shutdown behavior
- presentation feedback and graphics-preview fallback behavior
