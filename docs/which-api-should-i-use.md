# Which API Should I Use?

WaylandClientKit is the substrate layer. It exposes Wayland-facing app primitives
and keeps framework policy above the package. If a task sounds like layout,
widgets, styling, accessibility semantics, scene management, or renderer
selection, build that in your framework above WaylandClientKit.

| I want to... | Use | Capability gate | Example |
| --- | --- | --- | --- |
| Open a display connection | `WaylandDisplay.withConnection` | Wayland display availability | [WaylandClientKitDemo](../Examples/WaylandClientKitDemo/main.swift) |
| Create a window | `WaylandDisplay.createTopLevelWindow` | `xdg_wm_base` | [WaylandClientKitDemo](../Examples/WaylandClientKitDemo/main.swift) |
| Draw pixels | `Window.show`, `Window.redraw`, `SoftwareFrame` | `wl_shm` and xdg configure | [WaylandClientKitDemo](../Examples/WaylandClientKitDemo/main.swift) |
| Redraw part of a window | `SurfaceDamageRegion` with `Window.redraw(damage:_:)` | surface size and scale must validate | [DamageRegionSmoke](../Examples/DamageRegionSmoke/main.swift) |
| Shape input or opaque regions | `Window.setInputRegion`, `Window.setOpaqueRegion`, `SurfaceRegion` | `wl_compositor` regions | [SurfaceRegionSmoke](../Examples/SurfaceRegionSmoke/main.swift) |
| Create a child surface | `Window.createSubsurface`, `Subsurface` | `wl_subcompositor` | [SubsurfaceSmoke](../Examples/SubsurfaceSmoke/main.swift) |
| Use a custom cursor image | `PointerCursor.image(_:)`, `WaylandDisplay.setPointerCursor(_:)` | cursor surface support and pointer focus | [CustomCursorSmoke](../Examples/CustomCursorSmoke/main.swift) |
| Use an animated custom cursor | `PointerCursorFrame`, `AnimatedPointerCursor`, `PointerCursor.animated(_:)` | cursor surface support and pointer focus | [CursorAnimationSmoke](../Examples/CursorAnimationSmoke/main.swift) |
| Request compositor cursor shapes | `PointerCursor.shape(_:)` through `WaylandDisplay.setPointerCursor(_:)` | `wp_cursor_shape_manager_v1` | [CursorPolicySmoke](../Examples/CursorPolicySmoke/main.swift) |
| Set a window icon | `Window.setIcon(_:)` | `xdg_toplevel_icon_manager_v1` | [WindowIconSmoke](../Examples/WindowIconSmoke/main.swift) |
| Stop screen idle for a window | `Window.inhibitIdle()` | `zwp_idle_inhibit_manager_v1` | [IdleInhibitSmoke](../Examples/IdleInhibitSmoke/main.swift) |
| Ring the system bell | `WaylandDisplay.ringSystemBell()` or `Window.ringSystemBell()` | `xdg_system_bell_v1` | [SystemBellSmoke](../Examples/SystemBellSmoke/main.swift) |
| Receive local keyboard text and shortcuts | `InputEvent`, interpreted keyboard events | `wl_keyboard` plus keymap support | [WaylandClientKitDemo](../Examples/WaylandClientKitDemo/main.swift) |
| Receive compositor IME text | `TextInputSession` and `display.textInputEvents` | `zwp_text_input_manager_v3` | [TextInputSmoke](../Examples/TextInputSmoke/main.swift) |
| Capture relative pointer or lock/confine | `Window.relativePointer`, `Window.lockPointer`, `Window.confinePointer` | `zwp_relative_pointer_manager_v1`, `zwp_pointer_constraints_v1` | [PointerCaptureSmoke](../Examples/PointerCaptureSmoke/main.swift) |
| Request pointer warp | `Window.requestPointerWarp(seatID:position:serial:)` | `wp_pointer_warp_v1` plus a seat pointer and input serial | [PointerWarpSmoke](../Examples/PointerWarpSmoke/main.swift) |
| Use clipboard or drag-and-drop | `ClipboardOffer`, `ClipboardSource`, `DragOffer`, `DragSource`, `DragIcon` | `wl_data_device_manager`; primary selection has its own optional gate | [DataTransferSmoke](../Examples/DataTransferSmoke/main.swift) |
| Request activation/focus handoff | `Window.requestActivationToken`, `Window.activate(using:)` | `xdg_activation_v1` and compositor policy | [XDGActivationSmoke](../Examples/XDGActivationSmoke/main.swift) |
| Save framework-owned window restore facts | `Window.restorationSnapshot`, `WindowStateSnapshot`, `WindowRestorationSnapshot` | initial window configure must have happened | [SessionStateSmoke](../Examples/SessionStateSmoke/main.swift) |
| Time animation to real presentation | `Window.requestPresentationFeedback`, `Window.presentationEvents` | `wp_presentation` | [PresentationFeedbackAnimation](../Examples/PresentationFeedbackAnimation/main.swift) |
| Inspect optional protocol support | `WaylandDisplay.capabilities()` | registry discovery | [Capabilities DocC](../Sources/WaylandClient/WaylandClient.docc/CapabilitiesAndOptionalProtocols.md) |
| Try renderer-neutral GPU preview | `WaylandGraphicsPreview` values, `WaylandGraphicsWindowBacking`, frame leases | `zwp_linux_dmabuf_v1` plus surface-specific runtime setup | [Graphics preview docs](../Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc/WaylandGraphicsPreview.md) |
| Build real widgets, layout, styling, or accessibility semantics | Your framework above WaylandClientKit | framework policy | [Building A GUI Layer](building-a-gui-layer.md) |

Capability checks are advisory. Wayland globals can disappear or compositor
policy can reject a request after discovery. Public request APIs validate again
at use time and report typed errors or diagnostics.

## Where Policy Lives

WaylandClientKit owns:

- Wayland connection lifetime and owner-thread execution.
- Typed public identities for displays, windows, surfaces, seats, serials,
  events, and diagnostics.
- Software buffer presentation, damage validation, and capability-gated request
  plumbing.
- Renderer-neutral graphics preview facts and fallback results.

Your app or framework owns:

- Window routing, focus model, menu behavior, shortcuts, and command handling.
- Layout, widgets, styling, semantic accessibility, retained scene state, and
  renderer choice.
- Higher-level clipboard/drag MIME policy and text editing model.
- Scene identity, document identity, state serialization, and restore policy.
- Retry policy when optional compositor features are missing or rejected.
