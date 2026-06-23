# Support Matrix

This matrix describes the current experimental baseline. Status labels:

- Public: available through `WaylandClient`.
- Preview: public but source-breaking preview API.
- Internal preview: package-internal support used by preview work.
- Raw/generated: generated or raw wrapper support without a stable overlay.
- Unsupported: intentionally not in the current baseline.

## Core Protocols

| Protocol | Status | Notes |
| --- | --- | --- |
| `wl_display` | Public | Display connection lifecycle. |
| `wl_registry` | Public | Discovery and version negotiation. |
| `wl_callback` | Public | Frame callbacks and roundtrip helpers. |
| `wl_compositor` | Public | Managed surface creation. |
| `wl_surface` | Public | Managed windows, popups, cursors, drag icons, subsurfaces. |
| `wl_shm`, `wl_shm_pool`, `wl_buffer` | Public | Software frame path. |

## Windowing

| Protocol | Status | Notes |
| --- | --- | --- |
| `xdg_wm_base`, `xdg_surface`, `xdg_toplevel` | Public | Toplevel windows and configure lifecycle. |
| `xdg_popup`, `xdg_positioner` | Public | Popup placement and dismissal. |
| `zxdg_decoration_manager_v1`, `zxdg_toplevel_decoration_v1` | Public | Server-side decoration negotiation. |
| `xdg_wm_dialog_v1`, `xdg_dialog_v1` | Public | Dialog hints when advertised. |
| `xdg_toplevel_drag_manager_v1`, `xdg_toplevel_drag_v1` | Public | Toplevel drag start. |
| `xdg_activation_v1` | Public | Activation token and activation request helpers. |
| `ext_foreign_toplevel_list_v1`, `ext_foreign_toplevel_handle_v1` | Public | Read-only foreign toplevel facts. |

## Surface And Presentation

| Protocol | Status | Notes |
| --- | --- | --- |
| `wp_viewporter`, `wp_viewport` | Public | Scale-aware SHM buffer presentation. |
| `wp_fractional_scale_manager_v1`, `wp_fractional_scale_v1` | Public | Fractional scale facts. |
| `wp_presentation`, `wp_presentation_feedback` | Public | Presentation feedback requests and events. |
| `wp_content_type_manager_v1`, `wp_content_type_v1` | Internal preview | Surface commit metadata. |
| `wp_alpha_modifier_v1`, `wp_alpha_modifier_surface_v1` | Internal preview | Surface commit metadata. |
| `wp_tearing_control_manager_v1`, `wp_tearing_control_v1` | Internal preview | Surface commit metadata. |
| `wp_fifo_manager_v1`, `wp_fifo_v1` | Internal preview | Frame pacing preview facts. |
| `wp_commit_timing_manager_v1`, `wp_commit_timer_v1` | Internal preview | Frame scheduling preview facts. |

## Input

| Protocol | Status | Notes |
| --- | --- | --- |
| `wl_seat`, `wl_pointer`, `wl_keyboard`, `wl_touch` | Public | Typed input events and seat lifecycle. |
| `zwp_relative_pointer_manager_v1`, `zwp_relative_pointer_v1` | Public | Relative pointer events. |
| `zwp_pointer_constraints_v1`, `zwp_locked_pointer_v1`, `zwp_confined_pointer_v1` | Public | Pointer lock/confine requests and lifecycle. |
| `wp_pointer_warp_v1` | Public | Pointer warp requests when advertised. |
| `zwp_pointer_gestures_v1`, `zwp_pointer_gesture_swipe_v1`, `zwp_pointer_gesture_pinch_v1`, `zwp_pointer_gesture_hold_v1` | Public | Gesture facts. |
| `zwp_tablet_manager_v2` family | Public | Tablet input is surfaced through typed input events. |

## Data Transfer

| Protocol | Status | Notes |
| --- | --- | --- |
| `wl_data_device_manager`, `wl_data_device`, `wl_data_offer`, `wl_data_source` | Public | Clipboard and drag-and-drop. |
| `zwp_primary_selection_device_manager_v1`, `zwp_primary_selection_device_v1`, `zwp_primary_selection_offer_v1`, `zwp_primary_selection_source_v1` | Public | Primary selection offers and sources. |

## Text Input

| Protocol | Status | Notes |
| --- | --- | --- |
| `zwp_text_input_manager_v3`, `zwp_text_input_v3` | Public | Seat-scoped compositor/IME text entry. |

## Desktop Integration

| Protocol | Status | Notes |
| --- | --- | --- |
| `wp_cursor_shape_manager_v1`, `wp_cursor_shape_device_v1` | Public | Compositor cursor-shape requests. |
| `xdg_toplevel_icon_manager_v1`, `xdg_toplevel_icon_v1` | Public | Named and XRGB8888 toplevel icons. |
| `zwp_idle_inhibit_manager_v1`, `zwp_idle_inhibitor_v1` | Public | Surface-scoped idle inhibition. |
| `zwp_keyboard_shortcuts_inhibit_manager_v1`, `zwp_keyboard_shortcuts_inhibitor_v1` | Public | Shortcut inhibition requests. |
| `xdg_system_bell_v1` | Public | Compositor-mediated bell requests. |

## Graphics Preview

| Protocol or Area | Status | Notes |
| --- | --- | --- |
| `zwp_linux_dmabuf_v1`, `zwp_linux_dmabuf_feedback_v1`, `zwp_linux_buffer_params_v1` | Preview | Capability discovery, public format/modifier/device-identity facts, and public move-only external-buffer submission. |
| `wp_linux_drm_syncobj_manager_v1`, `wp_linux_drm_syncobj_surface_v1`, `wp_linux_drm_syncobj_timeline_v1` | Preview | Managed GPU and public move-only external-buffer explicit synchronization. Public API consumes descriptor ownership without exposing borrowed descriptor integers. |
| GBM/EGL/GLES/DRM shims | Internal preview | Package-internal managed GPU backing. |
| `WaylandGraphicsPreview` | Preview | Source-breaking public preview product. |

## Output And Color

| Protocol | Status | Notes |
| --- | --- | --- |
| `wl_output` | Public | Output facts and surface output membership. |
| `zxdg_output_manager_v1`, `zxdg_output_v1` | Public | Logical output geometry when advertised. |
| `zwlr_output_manager_v1`, `zwlr_output_head_v1`, `zwlr_output_mode_v1` | Preview | Public output-management facts/current configuration. |
| `zwlr_output_configuration_v1`, `zwlr_output_configuration_head_v1` | Preview | Public current/no-op test/apply preview paths. |
| `wp_color_representation_manager_v1`, `wp_color_representation_surface_v1` | Internal preview | Surface color metadata. |
| `wp_color_manager_v1`, `wp_color_management_surface_v1`, `wp_color_management_surface_feedback_v1`, `wp_color_management_output_v1` | Internal preview | Color-management metadata and facts. |
| `wp_image_description_v1`, `wp_image_description_reference_v1` | Internal preview | Color-management image descriptions. |

## Deferred, Raw Preview, Or Unsupported

| Area | Status | Notes |
| --- | --- | --- |
| General output-management mutation APIs | Unsupported | Only current/no-op preview configuration paths exist. |
| Stable public GPU rendering APIs in `WaylandClient` | Unsupported | Use `WaylandGraphicsPreview` for source-breaking experiments. |
| Public raw Wayland, GBM, EGL, DRM, dmabuf, syncobj, borrowed file descriptor, or unsafe handles | Unsupported | Raw handles stay internal. `WaylandGraphicsPreview` exposes renderer-neutral preview values, render-node device identity bytes, and move-only external-buffer descriptors that consume owned file descriptors. |
