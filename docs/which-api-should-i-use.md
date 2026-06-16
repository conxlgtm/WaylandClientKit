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
| Inspect outputs and window output membership | `WaylandDisplay.outputTopology()`, `Window.stateSnapshot.outputs` | `wl_output`, optional `zxdg_output_manager_v1` | [OutputTopologySmoke](../Examples/OutputTopologySmoke/main.swift) |
| Redraw part of a window | `SurfaceDamageRegion` with `Window.redraw(damage:_:)` | surface size and scale must validate | [DamageRegionSmoke](../Examples/DamageRegionSmoke/main.swift) |
| Shape input or opaque regions | `Window.setInputRegion`, `Window.setOpaqueRegion`, `SurfaceRegion` | `wl_compositor` regions | [SurfaceRegionSmoke](../Examples/SurfaceRegionSmoke/main.swift) |
| Create a child surface | `Window.createSubsurface`, `Subsurface` | `wl_subcompositor` | [SubsurfaceSmoke](../Examples/SubsurfaceSmoke/main.swift) |
| Use a custom cursor image | `PointerCursor.image(_:)`, `WaylandDisplay.setPointerCursor(_:)` | cursor surface support and pointer focus | [CustomCursorSmoke](../Examples/CustomCursorSmoke/main.swift) |
| Use an animated custom cursor | `PointerCursorFrame`, `AnimatedPointerCursor`, `PointerCursor.animated(_:)` | cursor surface support and pointer focus | [CursorAnimationSmoke](../Examples/CursorAnimationSmoke/main.swift) |
| Request compositor cursor shapes | `PointerCursor.shape(_:)` through `WaylandDisplay.setPointerCursor(_:)` | `wp_cursor_shape_manager_v1` | [CursorPolicySmoke](../Examples/CursorPolicySmoke/main.swift) |
| Set a window icon | `Window.setIcon(_:)` | `xdg_toplevel_icon_manager_v1` | [WindowIconSmoke](../Examples/WindowIconSmoke/main.swift) |
| Stop screen idle for a window | `Window.inhibitIdle()` | `zwp_idle_inhibit_manager_v1` | [IdleInhibitSmoke](../Examples/IdleInhibitSmoke/main.swift) |
| Mark one window as another window's dialog | `Window.createDialog(parent:modal:)` | `xdg_wm_dialog_v1`; modal is a protocol hint | [DialogSmoke](../Examples/DialogSmoke/main.swift) |
| Inhibit compositor keyboard shortcuts for a window and seat | `Window.inhibitKeyboardShortcuts(seatID:)` plus `keyboardShortcutsInhibitorChanged` events | `zwp_keyboard_shortcuts_inhibit_manager_v1` and compositor policy | [KeyboardShortcutsInhibitSmoke](../Examples/KeyboardShortcutsInhibitSmoke/main.swift) |
| Ring the system bell | `WaylandDisplay.ringSystemBell()` or `Window.ringSystemBell()` | `xdg_system_bell_v1` | [SystemBellSmoke](../Examples/SystemBellSmoke/main.swift) |
| Receive local keyboard text and shortcuts | `InputEvent`, interpreted keyboard events | `wl_keyboard` plus keymap support | [WaylandClientKitDemo](../Examples/WaylandClientKitDemo/main.swift) |
| Receive graphics tablet facts | `InputEventKind.tablet` and `WaylandDisplay.capabilities().tablet` | `zwp_tablet_manager_v2` plus tablet hardware/events | [TabletInputSmoke](../Examples/TabletInputSmoke/main.swift) |
| Receive compositor IME text | `TextInputSession` and `display.textInputEvents` | `zwp_text_input_manager_v3` | [TextInputSmoke](../Examples/TextInputSmoke/main.swift) |
| Capture relative pointer or lock/confine | `Window.relativePointer`, `Window.lockPointer`, `Window.confinePointer` | `zwp_relative_pointer_manager_v1`, `zwp_pointer_constraints_v1` | [PointerCaptureSmoke](../Examples/PointerCaptureSmoke/main.swift) |
| Receive touchpad gesture facts | `WaylandDisplay.pointerGestures(seatID:)`, `PointerGestureEvent` | `zwp_pointer_gestures_v1` plus compositor/hardware events | [PointerGesturesSmoke](../Examples/PointerGesturesSmoke/main.swift) |
| Request pointer warp | `Window.requestPointerWarp(seatID:position:serial:)` | `wp_pointer_warp_v1` plus a seat pointer and input serial | [PointerWarpSmoke](../Examples/PointerWarpSmoke/main.swift) |
| Use clipboard or drag-and-drop | `ClipboardOffer`, `ClipboardSource`, `DragOffer`, `DragSource`, `DragIcon` | `wl_data_device_manager`; primary selection has its own optional gate | [DataTransferSmoke](../Examples/DataTransferSmoke/main.swift) |
| Drag detachable content as a toplevel | `Window.startToplevelDrag(source:seatID:serial:icon:offset:)` | `xdg_toplevel_drag_manager_v1`, data-device drag support, and a live button serial | [ToplevelDragSmoke](../Examples/ToplevelDragSmoke/main.swift) |
| Request activation/focus handoff | `Window.requestActivationToken`, `Window.activate(using:)` | `xdg_activation_v1` and compositor policy | [XDGActivationSmoke](../Examples/XDGActivationSmoke/main.swift) |
| Save framework-owned window restore facts | `Window.restorationSnapshot`, `WindowStateSnapshot`, `WindowRestorationSnapshot` | initial window configure must have happened | [SessionStateSmoke](../Examples/SessionStateSmoke/main.swift) |
| Inspect compositor session protocol facts | `WaylandDisplay.compositorSessionEvents(reason:existingID:)` | `xdg_session_manager_v1`; local restore remains framework-owned | [CompositorSessionSmoke](../Examples/CompositorSessionSmoke/main.swift) |
| Inspect read-only foreign toplevel facts | `WaylandDisplay.foreignToplevelListSnapshot()` | `ext_foreign_toplevel_list_v1`; titles/app IDs are optional and privacy-sensitive | [ForeignToplevelListSmoke](../Examples/ForeignToplevelListSmoke/main.swift) |
| Inspect output-management facts or test current config | `WaylandDisplay.outputManagementSnapshot()`, `OutputConfigurationProposal(current:)`, `testOutputConfiguration(_:)` | `zwlr_output_manager_v1`; mutation is preview and explicit | [OutputManagementSmoke](../Examples/OutputManagementSmoke/main.swift) |
| Time animation to real presentation | `Window.requestPresentationFeedback`, `Window.presentationEvents` | `wp_presentation` | [PresentationFeedbackAnimation](../Examples/PresentationFeedbackAnimation/main.swift) |
| Inspect optional protocol support | `WaylandDisplay.capabilities()` | registry discovery | [Capabilities DocC](../Sources/WaylandClient/WaylandClient.docc/CapabilitiesAndOptionalProtocols.md) |
| Try renderer-neutral GPU preview | `WaylandGraphicsPreview` values, `WaylandGraphicsWindowBacking`, frame leases | `zwp_linux_dmabuf_v1` plus surface-specific runtime setup | [Graphics preview docs](../Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc/WaylandGraphicsPreview.md) |
| Submit an external GPU buffer | `WaylandGraphicsFrameLease.submitExternalBuffer`; maintainer probe: `GraphicsPreviewExternalBufferSmoke -- --probe` | `zwp_linux_dmabuf_v1`; active import needs compositor and renderer dmabuf support | [External buffer docs](../Sources/WaylandGraphicsPreviewAPI/WaylandGraphicsPreview.docc/ExternalBufferSubmission.md) |
| Request preview frame scheduling | `WaylandGraphicsFrameSchedule` | explicit sync, FIFO, commit timing, or presentation protocols as requested | [GraphicsPreviewManagedGPUClear](../Examples/GraphicsPreviewManagedGPUClear/main.swift) |
| Report color metadata facts | `WaylandGraphicsFrameMetadata`, color runtime path facts | color metadata protocols where advertised | [ColorManagementSmoke](../Examples/ColorManagementSmoke/main.swift) |
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
- Output topology, output-management preview facts, and color metadata facts
  without general monitor settings or renderer color policy.

Your app or framework owns:

- Window routing, focus model, menu behavior, shortcuts, and command handling.
- Layout, widgets, styling, semantic accessibility, retained scene state, and
  renderer choice.
- Higher-level clipboard/drag MIME policy and text editing model.
- Scene identity, document identity, state serialization, and restore policy.
- Retry policy when optional compositor features are missing or rejected.
