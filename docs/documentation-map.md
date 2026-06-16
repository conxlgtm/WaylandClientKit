# Documentation Map

WaylandClientKit documentation has five layers. Each layer has one job so users,
framework authors, and maintainers do not have to reverse-engineer the package
layout.

## User Entry Points

- [README](../README.md): project scope, quick start, support status, and links
  to the next document to read.
- [Getting Started](getting-started.md): linear first-client path from
  dependency checks to a small window that draws pixels.
- [Which API Should I Use?](which-api-should-i-use.md): task-oriented guide
  that maps common app/framework needs to public WaylandClientKit APIs.
- [Session Readiness](session-readiness.md): app/window restoration boundary for
  future framework authors.

## Public API Reference And Concepts

- [WaylandClient DocC catalog](../Sources/WaylandClient/WaylandClient.docc/WaylandClient.md):
  stable-ish public app-substrate API for display lifecycle, windows, software
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

## Maintainer Docs

The [docs](.) directory contains project operation and design records:

- [Architecture](architecture.md)
- [Compatibility policy](compatibility-policy.md)
- [Foundation candidate status](foundation-candidate-status.md)
- [Foundation evidence report](foundation-evidence-report.md)
- [Release process](release.md)
- [Tooling](tooling.md)
- [Public API audit](public-api-audit.md)
- [Strict memory-safety audit](strict-memory-safety-audit.md)
- [Compositor matrix](compositor-matrix.md)
- [Session management plan](session-management-plan.md)

Maintainer docs may describe internal targets and release gates. User docs
should link here only when the reader needs project policy, evidence, or release
discipline.

## Runnable Examples

`Examples/` contains small runnable targets. Examples are not compatibility
promises, but they are build-gated and should remain useful as proof of public
APIs.

Canonical examples by feature:

| Feature | Example |
| --- | --- |
| Basic software window and input | [WaylandClientKitDemo](../Examples/WaylandClientKitDemo/main.swift) |
| Framework host loop | [FrameworkHostSmoke](../Examples/FrameworkHostSmoke/main.swift) |
| Session state and restoration facts | [SessionStateSmoke](../Examples/SessionStateSmoke/main.swift), [CompositorSessionSmoke](../Examples/CompositorSessionSmoke/main.swift) |
| Presentation timing | [PresentationFeedbackAnimation](../Examples/PresentationFeedbackAnimation/main.swift) |
| Output topology | [OutputTopologySmoke](../Examples/OutputTopologySmoke/main.swift) |
| Text input | [TextInputSmoke](../Examples/TextInputSmoke/main.swift) |
| Data transfer and drag icons | [DataTransferSmoke](../Examples/DataTransferSmoke/main.swift) |
| Tablet input | [TabletInputSmoke](../Examples/TabletInputSmoke/main.swift) |
| Pointer capture, warp, and gestures | [PointerCaptureSmoke](../Examples/PointerCaptureSmoke/main.swift), [PointerWarpSmoke](../Examples/PointerWarpSmoke/main.swift), [PointerGesturesSmoke](../Examples/PointerGesturesSmoke/main.swift) |
| Cursor policy and custom cursor images | [CursorPolicySmoke](../Examples/CursorPolicySmoke/main.swift), [CustomCursorSmoke](../Examples/CustomCursorSmoke/main.swift), [CursorAnimationSmoke](../Examples/CursorAnimationSmoke/main.swift) |
| Desktop integration | [WindowIconSmoke](../Examples/WindowIconSmoke/main.swift), [IdleInhibitSmoke](../Examples/IdleInhibitSmoke/main.swift), [DialogSmoke](../Examples/DialogSmoke/main.swift), [KeyboardShortcutsInhibitSmoke](../Examples/KeyboardShortcutsInhibitSmoke/main.swift), [ToplevelDragSmoke](../Examples/ToplevelDragSmoke/main.swift), [SystemBellSmoke](../Examples/SystemBellSmoke/main.swift) |
| Foreign toplevel and output-management preview | [ForeignToplevelListSmoke](../Examples/ForeignToplevelListSmoke/main.swift), [OutputManagementSmoke](../Examples/OutputManagementSmoke/main.swift) |
| Surface regions and damage | [SurfaceRegionSmoke](../Examples/SurfaceRegionSmoke/main.swift), [DamageRegionSmoke](../Examples/DamageRegionSmoke/main.swift) |
| Subsurfaces | [SubsurfaceSmoke](../Examples/SubsurfaceSmoke/main.swift) |
| Graphics preview | [GPUPreviewSmokeClient](../Examples/GPUPreviewSmokeClient/main.swift), [GraphicsPreviewManagedGPUClear](../Examples/GraphicsPreviewManagedGPUClear/main.swift), [GraphicsPreviewExternalBufferSmoke](../Examples/GraphicsPreviewExternalBufferSmoke/main.swift), [GraphicsPreviewColorMetadataSmoke](../Examples/GraphicsPreviewColorMetadataSmoke/main.swift), [ColorManagementSmoke](../Examples/ColorManagementSmoke/main.swift) |

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
| App/window restoration and compositor session facts | [Session Readiness](../Sources/WaylandClient/WaylandClient.docc/SessionReadiness.md) |

If a new public API family is added, add or update its canonical conceptual doc
first, then link examples and maintainer evidence from that doc.
