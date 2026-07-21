# Development Checkpoint Checklist

Tags are development checkpoints, not API-stability promises. Public API,
documentation, support status, and compositor evidence must agree before a tag.

Review [Compatibility Policy](compatibility-policy.md) for public API changes and
[Compositor Matrix](compositor-matrix.md) for runtime claims.

## Required Gates

Run from a clean working tree:

```bash
swift run wck tools toolchain-smoke
swift run wck ci release
swift run wck examples build
swift run wck compositor evidence-summary
swift run wck api dump
```

`ci release` runs the release build and tests, generated-file and shim checks,
DocC verification, public API verification, and an available live or headless
Wayland path.

`compositor evidence-summary` reports incomplete cells in the compositor matrix.
It does not replace review of the recorded command output.

Use `swift run wck ci foundation-check` only for a foundation-candidate claim.
It rejects incomplete compositor cells, environment skips, and manual-interaction
gaps.

## Additional Runtime Checks

Run sanitizer jobs where the host supports them:

```bash
swift run wck test tsan
swift run wck test asan
swift run wck smoke headless -- wck test request-paths
swift run wck smoke headless -- wck test request-paths-tsan
swift run wck smoke headless -- wck test request-paths-asan
```

AddressSanitizer uses `detect_leaks=0`; leak checks are informational because
Swift and XCTest runtime allocations vary by host. ThreadSanitizer uses
`safety/tsan-suppressions.txt` for named Swift runtime and libdispatch reports.
Project race reports must remain unsuppressed.

Under a desktop Wayland session, run:

```bash
swift run wck smoke live
swift run wck smoke integration
swift run wck smoke gpu-preview
swift run GraphicsPreviewManagedGPUClear -- --auto-close --print-summary
swift run --package-path Examples WaylandClientKitDemo
```

Record the compositor name, version, advertised protocols, runtime path, and
results in [Compositor Matrix](compositor-matrix.md). Weston-only results do not
establish compatibility with Mutter, KWin, or wlroots compositors.

Graphics preview claims include the runtime-path block from `smoke gpu-preview`,
the managed-GPU example result when available, exact missing interfaces, and any
advertised-but-broken path. An active managed GPU result requires a successful
live compositor run.

See [Linux Live Wayland Testing](live-wayland-testing.md) for command behavior
and optional-protocol skips.

## Tag Sequence

1. Confirm the working tree is clean and Swift 6.3.2 or newer is active.
2. Run the required gates.
3. Run applicable sanitizer and live compositor checks.
4. Update `docs/compositor-matrix.md` with command output and environment facts.
5. Review `docs/public-api-audit.md` and the generated public API report.
6. Update README and DocC support statements for user-visible changes.
7. Confirm protocol generation produces no diff.
8. Tag the checkpoint.

A tag can wait until required commands pass and public API, generated-file, shim,
documentation, and compositor-evidence changes have been reviewed.
