# Documentation Map

WaylandClientKit documentation is split into public entry points, API reference,
and maintainer policy records.

## User Entry Points

- [README](../README.md): project scope, quick start, support status, and links
  to the next document to read.
- [Getting Started](getting-started.md): linear first-client path from
  dependency checks to a small window that draws pixels.
- [Which API Should I Use?](which-api-should-i-use.md): task-oriented guide
  that maps common app/framework needs to public WaylandClientKit APIs.
- [Support Matrix](support-matrix.md): public, preview, internal preview,
  raw/generated, and unsupported protocol coverage.
- [Linux Dependencies](linux-dependencies.md): distro package hints and
  toolchain capability checks.

## Public API Reference And Concepts

- [WaylandClient DocC catalog](../Sources/WaylandClient/WaylandClient.docc/WaylandClient.md):
  main public app-substrate API for display lifecycle, windows, software
  drawing, input, data transfer, text input, cursor policy, presentation
  feedback, diagnostics, and optional protocol capabilities.
- [WaylandGraphicsPreview DocC catalog](../Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc/WaylandGraphicsPreview.md):
  source-breaking preview API for renderer-neutral graphics backing selection,
  frame leases, runtime path reporting, managed GPU attempts, and software
  fallback.

`WaylandClient` is the main public product. It is still pre-foundation, but
public API changes are baseline and audit tracked. `WaylandGraphicsPreview` is
explicitly preview and may change source compatibility, but preview API drift is
still reviewed and documented.

## Maintainer Policy

Use these for repository operation and release review:

- [Compatibility policy](compatibility-policy.md)
- [Versioning](versioning.md)
- [Release process](release.md)
- [Tooling](tooling.md)
- [Public API audit](public-api-audit.md)
- [Strict memory-safety audit](strict-memory-safety-audit.md)
- [Compositor matrix](compositor-matrix.md)

## Runnable Examples

`Examples/` contains runnable targets grouped by feature. Start with
[WaylandClientKitDemo](../Examples/WaylandClientKitDemo/main.swift), then use
[Which API Should I Use?](which-api-should-i-use.md) to find feature-specific
examples.

## Canonical Concept Documents

Every public feature family should have one conceptual home:

| Public feature family | Canonical conceptual doc |
| --- | --- |
| Display lifecycle and connection ownership | [Display Lifecycle](../Sources/WaylandClient/WaylandClient.docc/DisplayLifecycle.md) |
| Output topology and membership | [Output Topology](../Sources/WaylandClient/WaylandClient.docc/OutputTopology.md) |
| Software frame drawing and redraw sequencing | [Window Drawing](../Sources/WaylandClient/WaylandClient.docc/WindowDrawing.md) |
| Surface regions and partial damage | [Surface Regions And Damage](../Sources/WaylandClient/WaylandClient.docc/SurfaceRegionsAndDamage.md) |
| Subsurfaces | [Subsurfaces](../Sources/WaylandClient/WaylandClient.docc/Subsurfaces.md) |
| Cursor shape, theme fallback, and custom images | [Cursor Shape And Theme Fallback](../Sources/WaylandClient/WaylandClient.docc/CursorShapeAndThemeFallback.md) |
| Desktop icons, dialog hints, shortcut inhibition, toplevel drag, and system bell | [Desktop Integration](../Sources/WaylandClient/WaylandClient.docc/DesktopIntegration.md) |
| Activation and focus handoff | [Activation And Focus Handoff](../Sources/WaylandClient/WaylandClient.docc/ActivationAndFocusHandoff.md) |
| Pointer capture, relative pointer, pointer warp, and gestures | [Pointer Capture](../Sources/WaylandClient/WaylandClient.docc/PointerCapture.md) |
| Tablet input | [Tablet Input](../Sources/WaylandClient/WaylandClient.docc/TabletInput.md) |
| Data transfer and drag icons | [Data Transfer And Drag Icons](../Sources/WaylandClient/WaylandClient.docc/DataTransferAndDragIcons.md) |
| Text input lifecycle | [Text Input Lifecycle](../Sources/WaylandClient/WaylandClient.docc/TextInputLifecycle.md) |
| Presentation feedback and animation | [Presentation Feedback And Frame Callbacks](../Sources/WaylandClient/WaylandClient.docc/PresentationFeedbackAndFrameCallbacks.md) |
| Diagnostics and event overflow | [Diagnostics And Display Failures](../Sources/WaylandClient/WaylandClient.docc/DiagnosticsAndDisplayFailures.md), [Event Streams And Overflow](../Sources/WaylandClient/WaylandClient.docc/EventStreamsAndOverflow.md) |
| Graphics preview | [Graphics Preview Overview](../Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc/GraphicsPreviewOverview.md), [External Buffer Submission](../Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc/ExternalBufferSubmission.md), [Scheduling And Color Metadata](../Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc/SchedulingAndColorMetadata.md) |
| App/window restoration and compositor session capability | [Session Readiness](../Sources/WaylandClient/WaylandClient.docc/SessionReadiness.md) |

If a new public API family is added, add or update its canonical conceptual doc
first, then link examples and maintainer evidence from that doc.
