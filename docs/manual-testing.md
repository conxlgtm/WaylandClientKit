# Manual Testing

Manual compositor checks should use `swift run` from the repository root or
`nix develop -c swift run ...` when using the Nix development shell.

Record live compositor facts in `docs/compositor-matrix.md`. Keep unit-test
results separate from compositor evidence. After updating the matrix, run:

```bash
swift run wck compositor evidence-summary
```

## Baseline

Run the noninteractive checks first:

```bash
swift run wck smoke live
swift run wck smoke integration
swift run wck smoke gpu-preview
```

For headless Weston:

```bash
swift run wck smoke headless -- wck smoke integration
swift run wck smoke headless -- wck smoke gpu-preview
```

## Framework-Facing Examples

Run the manual interaction probes:

```bash
swift run ClientSideResizeChrome
swift run SerialActionsProbe
swift run XDGActivationSmoke
swift run PointerCaptureSmoke
swift run PointerWarpSmoke -- --auto-close --print-summary
swift run CursorPolicySmoke
swift run CursorAnimationSmoke -- --auto-close --print-summary
swift run GraphicsPreviewManagedGPUClear
```

Run bounded examples when a compositor session is available:

```bash
swift run TwoWindowFrameworkHost -- --auto-close --print-summary
swift run TwoWindowOrderStress -- --duration-seconds 3 --print-summary
swift run TextInputSmoke -- --auto-close --print-summary
swift run TabletInputSmoke -- --auto-close --print-summary
swift run CompositorSessionSmoke -- --auto-close --print-summary
swift run DataTransferSmoke -- --auto-close --print-summary
swift run PresentationFeedbackAnimation -- --duration-seconds 3 --print-summary
swift run GPUPreviewSmokeClient
swift run GraphicsPreviewManagedGPUClear -- --auto-close --print-summary
```

## Notes To Capture

- compositor name and version
- advertised optional protocols
- client-side resize and cursor cleanup result
- serial-sensitive resize, move, menu, and drag-source result
- xdg activation capability, token request result, and activate request result
- relative pointer and pointer lock/confine capability and request result
- cursor shape, theme fallback, focused-output scale policy, and close result
- pointer warp and tablet capability, request/event result, and skip reason
- text-input capability, IME commits, and interpreted keyboard fallback
- clipboard, primary-selection, drag/drop, private MIME, and stale-offer behavior
- popup lifecycle and shutdown behavior
- presentation feedback, graphics-preview fallback behavior, and managed GPU
  resize/redraw frame sizes
