#pragma once

#ifndef __linux__
#error "WaylandClientKit currently supports Linux only."
#endif

#include <stdint.h>
#include <stddef.h>
#include <sys/types.h>
#include <wayland-client.h>

struct xdg_wm_base;
struct xdg_surface;
struct xdg_toplevel;
struct xdg_positioner;
struct xdg_popup;
struct zxdg_decoration_manager_v1;
struct zxdg_toplevel_decoration_v1;
struct zxdg_output_manager_v1;
struct zxdg_output_v1;
struct wp_viewporter;
struct wp_viewport;
struct wp_presentation;
struct wp_presentation_feedback;
struct wp_fractional_scale_manager_v1;
struct wp_fractional_scale_v1;
struct wp_cursor_shape_manager_v1;
struct wp_cursor_shape_device_v1;
struct xdg_activation_v1;
struct xdg_activation_token_v1;
struct xdg_session_manager_v1;
struct xdg_session_v1;
struct xdg_toplevel_session_v1;
struct xdg_toplevel_icon_manager_v1;
struct xdg_toplevel_icon_v1;
struct xdg_system_bell_v1;
struct xdg_wm_dialog_v1;
struct xdg_dialog_v1;
struct xdg_toplevel_drag_manager_v1;
struct xdg_toplevel_drag_v1;
struct ext_foreign_toplevel_list_v1;
struct ext_foreign_toplevel_handle_v1;
struct wp_pointer_warp_v1;
struct zwp_tablet_manager_v2;
struct zwp_tablet_seat_v2;
struct zwp_tablet_v2;
struct zwp_tablet_tool_v2;
struct zwp_tablet_pad_v2;
struct zwp_tablet_pad_group_v2;
struct zwp_tablet_pad_ring_v2;
struct zwp_tablet_pad_strip_v2;
struct zwp_tablet_pad_dial_v2;
struct zwp_relative_pointer_manager_v1;
struct zwp_relative_pointer_v1;
struct zwp_pointer_constraints_v1;
struct zwp_locked_pointer_v1;
struct zwp_confined_pointer_v1;
struct zwp_pointer_gestures_v1;
struct zwp_pointer_gesture_swipe_v1;
struct zwp_pointer_gesture_pinch_v1;
struct zwp_pointer_gesture_hold_v1;
struct zwp_keyboard_shortcuts_inhibit_manager_v1;
struct zwp_keyboard_shortcuts_inhibitor_v1;
struct zwp_idle_inhibit_manager_v1;
struct zwp_idle_inhibitor_v1;
struct wp_linux_drm_syncobj_manager_v1;
struct wp_linux_drm_syncobj_surface_v1;
struct wp_linux_drm_syncobj_timeline_v1;
struct wp_fifo_manager_v1;
struct wp_fifo_v1;
struct wp_commit_timing_manager_v1;
struct wp_commit_timer_v1;
struct wp_content_type_manager_v1;
struct wp_content_type_v1;
struct wp_alpha_modifier_v1;
struct wp_alpha_modifier_surface_v1;
struct wp_tearing_control_manager_v1;
struct wp_tearing_control_v1;
struct wp_color_representation_manager_v1;
struct wp_color_representation_surface_v1;
struct wp_color_manager_v1;
struct wp_color_management_output_v1;
struct wp_color_management_surface_v1;
struct wp_color_management_surface_feedback_v1;
struct wp_image_description_v1;
struct wp_image_description_reference_v1;
struct zwp_linux_dmabuf_v1;
struct zwp_linux_buffer_params_v1;
struct zwp_linux_dmabuf_feedback_v1;
struct wl_data_device_manager;
struct wl_data_device;
struct wl_data_offer;
struct wl_data_source;
struct wl_subcompositor;
struct wl_subsurface;
struct zwp_primary_selection_device_manager_v1;
struct zwp_primary_selection_device_v1;
struct zwp_primary_selection_offer_v1;
struct zwp_primary_selection_source_v1;
struct zwp_text_input_manager_v3;
struct zwp_text_input_v3;
struct zwlr_output_manager_v1;
struct zwlr_output_head_v1;
struct zwlr_output_mode_v1;
struct zwlr_output_configuration_v1;
struct zwlr_output_configuration_head_v1;

#ifdef __cplusplus
extern "C" {
#endif

#include "generated/shims/registry-bind-bridges.h"
#include "generated/shims/request-bridges.h"

/* ------------------------------------------------------------------ */
/*  Core request wrappers                                             */
/* ------------------------------------------------------------------ */

struct wl_subsurface *swl_subcompositor_get_subsurface(
    struct wl_subcompositor *subcompositor,
    struct wl_surface *surface,
    struct wl_surface *parent);

struct wl_shm_pool *swl_shm_create_pool(struct wl_shm *shm, int32_t fd, int32_t size);

struct wl_buffer *swl_shm_pool_create_buffer(
    struct wl_shm_pool *pool, int32_t offset, int32_t width,
    int32_t height, int32_t stride, uint32_t format);

void swl_surface_attach(
    struct wl_surface *surface, struct wl_buffer *buffer, int32_t x, int32_t y);
void swl_surface_commit(struct wl_surface *surface);
void swl_surface_damage_buffer(
    struct wl_surface *surface, int32_t x, int32_t y,
    int32_t width, int32_t height);
// for older wl_surface versions
void swl_surface_damage(struct wl_surface *surface, int32_t xd, int32_t y, int32_t width, int32_t height);
void swl_surface_set_opaque_region(
    struct wl_surface *surface, struct wl_region *region);
void swl_surface_set_input_region(
    struct wl_surface *surface, struct wl_region *region);
void swl_subsurface_set_position(
    struct wl_subsurface *subsurface,
    int32_t x,
    int32_t y);
void swl_subsurface_place_above(
    struct wl_subsurface *subsurface,
    struct wl_surface *sibling);
void swl_subsurface_place_below(
    struct wl_subsurface *subsurface,
    struct wl_surface *sibling);
void swl_subsurface_set_sync(struct wl_subsurface *subsurface);
void swl_subsurface_set_desync(struct wl_subsurface *subsurface);

uint32_t swl_shm_format_xrgb8888(void);
uint32_t swl_shm_format_argb8888(void);

/* ------------------------------------------------------------------ */
/*  Data-device request wrappers                                      */
/* ------------------------------------------------------------------ */

void swl_data_source_offer(struct wl_data_source *source, const char *mime_type);
void swl_data_source_set_actions(struct wl_data_source *source, uint32_t dnd_actions);
void swl_data_offer_accept(
    struct wl_data_offer *offer, uint32_t serial, const char *mime_type);
void swl_data_offer_receive(
    struct wl_data_offer *offer, const char *mime_type, int32_t fd);
void swl_data_offer_finish(struct wl_data_offer *offer);
void swl_data_offer_set_actions(
    struct wl_data_offer *offer, uint32_t dnd_actions, uint32_t preferred_action);
void swl_data_device_set_selection(
    struct wl_data_device *device, struct wl_data_source *source, uint32_t serial);
void swl_data_device_start_drag(
    struct wl_data_device *device,
    struct wl_data_source *source,
    struct wl_surface *origin,
    struct wl_surface *icon,
    uint32_t serial);
uint32_t swl_data_device_manager_dnd_action_none(void);
uint32_t swl_data_device_manager_dnd_action_copy(void);
uint32_t swl_data_device_manager_dnd_action_move(void);
uint32_t swl_data_device_manager_dnd_action_ask(void);

/* ------------------------------------------------------------------ */
/*  Primary-selection request wrappers                                */
/* ------------------------------------------------------------------ */

void swl_primary_selection_source_offer(
    struct zwp_primary_selection_source_v1 *source,
    const char *mime_type);
void swl_primary_selection_offer_receive(
    struct zwp_primary_selection_offer_v1 *offer,
    const char *mime_type,
    int32_t fd);
void swl_primary_selection_device_set_selection(
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_source_v1 *source,
    uint32_t serial);

/* ------------------------------------------------------------------ */
/*  Text-input request wrappers                                       */
/* ------------------------------------------------------------------ */

struct zwp_text_input_v3 *swl_text_input_manager_v3_get_text_input(
    struct zwp_text_input_manager_v3 *manager,
    struct wl_seat *seat);
void swl_text_input_v3_enable(struct zwp_text_input_v3 *text_input);
void swl_text_input_v3_disable(struct zwp_text_input_v3 *text_input);
void swl_text_input_v3_set_surrounding_text(
    struct zwp_text_input_v3 *text_input,
    const char *text,
    int32_t cursor,
    int32_t anchor);
void swl_text_input_v3_set_text_change_cause(
    struct zwp_text_input_v3 *text_input,
    uint32_t cause);
void swl_text_input_v3_set_content_type(
    struct zwp_text_input_v3 *text_input,
    uint32_t hint,
    uint32_t purpose);
void swl_text_input_v3_set_cursor_rectangle(
    struct zwp_text_input_v3 *text_input,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height);
void swl_text_input_v3_commit(struct zwp_text_input_v3 *text_input);
void swl_text_input_v3_show_input_panel(struct zwp_text_input_v3 *text_input);
void swl_text_input_v3_hide_input_panel(struct zwp_text_input_v3 *text_input);

/* ------------------------------------------------------------------ */
/*  XDG activation request wrappers                                   */
/* ------------------------------------------------------------------ */

struct xdg_activation_token_v1 *swl_xdg_activation_v1_get_activation_token(
    struct xdg_activation_v1 *activation);
void swl_xdg_activation_v1_activate(
    struct xdg_activation_v1 *activation,
    const char *token,
    struct wl_surface *surface);
void swl_xdg_activation_token_v1_set_serial(
    struct xdg_activation_token_v1 *token,
    uint32_t serial,
    struct wl_seat *seat);
void swl_xdg_activation_token_v1_set_app_id(
    struct xdg_activation_token_v1 *token,
    const char *app_id);
void swl_xdg_activation_token_v1_set_surface(
    struct xdg_activation_token_v1 *token,
    struct wl_surface *surface);
void swl_xdg_activation_token_v1_commit(
    struct xdg_activation_token_v1 *token);

/* ------------------------------------------------------------------ */
/*  Desktop integration request wrappers                              */
/* ------------------------------------------------------------------ */

struct xdg_toplevel_icon_v1 *
swl_xdg_toplevel_icon_manager_v1_create_icon(
    struct xdg_toplevel_icon_manager_v1 *manager);
void swl_xdg_toplevel_icon_manager_v1_set_icon(
    struct xdg_toplevel_icon_manager_v1 *manager,
    struct xdg_toplevel *toplevel,
    struct xdg_toplevel_icon_v1 *icon);
void swl_xdg_toplevel_icon_v1_set_name(
    struct xdg_toplevel_icon_v1 *icon,
    const char *name);
void swl_xdg_toplevel_icon_v1_add_buffer(
    struct xdg_toplevel_icon_v1 *icon,
    struct wl_buffer *buffer,
    int32_t scale);
struct zwp_idle_inhibitor_v1 *
swl_zwp_idle_inhibit_manager_v1_create_inhibitor(
    struct zwp_idle_inhibit_manager_v1 *manager,
    struct wl_surface *surface);
void swl_xdg_system_bell_v1_ring(
    struct xdg_system_bell_v1 *bell,
    struct wl_surface *surface);
void swl_xdg_wm_dialog_v1_destroy(struct xdg_wm_dialog_v1 *manager);
struct xdg_dialog_v1 *swl_xdg_wm_dialog_v1_get_xdg_dialog(
    struct xdg_wm_dialog_v1 *manager,
    struct xdg_toplevel *toplevel);
void swl_xdg_dialog_v1_destroy(struct xdg_dialog_v1 *dialog);
void swl_xdg_dialog_v1_set_modal(struct xdg_dialog_v1 *dialog);
void swl_xdg_dialog_v1_unset_modal(struct xdg_dialog_v1 *dialog);
void swl_xdg_toplevel_drag_manager_v1_destroy(
    struct xdg_toplevel_drag_manager_v1 *manager);
struct xdg_toplevel_drag_v1 *swl_xdg_toplevel_drag_manager_v1_get_xdg_toplevel_drag(
    struct xdg_toplevel_drag_manager_v1 *manager,
    struct wl_data_source *source);
void swl_xdg_toplevel_drag_v1_destroy(struct xdg_toplevel_drag_v1 *drag);
void swl_xdg_toplevel_drag_v1_attach(
    struct xdg_toplevel_drag_v1 *drag,
    struct xdg_toplevel *toplevel,
    int32_t x_offset,
    int32_t y_offset);
void swl_ext_foreign_toplevel_list_v1_stop(
    struct ext_foreign_toplevel_list_v1 *list);
void swl_ext_foreign_toplevel_list_v1_destroy(
    struct ext_foreign_toplevel_list_v1 *list);
void swl_ext_foreign_toplevel_handle_v1_destroy(
    struct ext_foreign_toplevel_handle_v1 *handle);

/* ------------------------------------------------------------------ */
/*  Pointer capture request wrappers                                  */
/* ------------------------------------------------------------------ */

void swl_wp_pointer_warp_v1_warp_pointer(
    struct wp_pointer_warp_v1 *warp,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    int32_t x,
    int32_t y,
    uint32_t serial);
void swl_wp_pointer_warp_v1_destroy(
    struct wp_pointer_warp_v1 *warp);

struct zwp_relative_pointer_v1 *
swl_zwp_relative_pointer_manager_v1_get_relative_pointer(
    struct zwp_relative_pointer_manager_v1 *manager,
    struct wl_pointer *pointer);
void swl_zwp_relative_pointer_manager_v1_destroy(
    struct zwp_relative_pointer_manager_v1 *manager);
void swl_zwp_relative_pointer_v1_destroy(
    struct zwp_relative_pointer_v1 *relative_pointer);

struct zwp_locked_pointer_v1 *
swl_zwp_pointer_constraints_v1_lock_pointer(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime);
struct zwp_confined_pointer_v1 *
swl_zwp_pointer_constraints_v1_confine_pointer(
    struct zwp_pointer_constraints_v1 *constraints,
    struct wl_surface *surface,
    struct wl_pointer *pointer,
    struct wl_region *region,
    uint32_t lifetime);
void swl_zwp_pointer_constraints_v1_destroy(
    struct zwp_pointer_constraints_v1 *constraints);
void swl_zwp_locked_pointer_v1_set_cursor_position_hint(
    struct zwp_locked_pointer_v1 *locked_pointer,
    int32_t surface_x,
    int32_t surface_y);
void swl_zwp_locked_pointer_v1_set_region(
    struct zwp_locked_pointer_v1 *locked_pointer,
    struct wl_region *region);
void swl_zwp_locked_pointer_v1_destroy(
    struct zwp_locked_pointer_v1 *locked_pointer);
void swl_zwp_confined_pointer_v1_set_region(
    struct zwp_confined_pointer_v1 *confined_pointer,
    struct wl_region *region);
void swl_zwp_confined_pointer_v1_destroy(
    struct zwp_confined_pointer_v1 *confined_pointer);

struct zwp_pointer_gesture_swipe_v1 *
swl_zwp_pointer_gestures_v1_get_swipe_gesture(
    struct zwp_pointer_gestures_v1 *gestures,
    struct wl_pointer *pointer);
struct zwp_pointer_gesture_pinch_v1 *
swl_zwp_pointer_gestures_v1_get_pinch_gesture(
    struct zwp_pointer_gestures_v1 *gestures,
    struct wl_pointer *pointer);
struct zwp_pointer_gesture_hold_v1 *
swl_zwp_pointer_gestures_v1_get_hold_gesture(
    struct zwp_pointer_gestures_v1 *gestures,
    struct wl_pointer *pointer);
void swl_zwp_pointer_gestures_v1_destroy(
    struct zwp_pointer_gestures_v1 *gestures);
void swl_zwp_pointer_gestures_v1_release(
    struct zwp_pointer_gestures_v1 *gestures);
void swl_zwp_pointer_gesture_swipe_v1_destroy(
    struct zwp_pointer_gesture_swipe_v1 *gesture);
void swl_zwp_pointer_gesture_pinch_v1_destroy(
    struct zwp_pointer_gesture_pinch_v1 *gesture);
void swl_zwp_pointer_gesture_hold_v1_destroy(
    struct zwp_pointer_gesture_hold_v1 *gesture);
void swl_zwp_keyboard_shortcuts_inhibit_manager_v1_destroy(
    struct zwp_keyboard_shortcuts_inhibit_manager_v1 *manager);
struct zwp_keyboard_shortcuts_inhibitor_v1 *
swl_zwp_keyboard_shortcuts_inhibit_manager_v1_inhibit_shortcuts(
    struct zwp_keyboard_shortcuts_inhibit_manager_v1 *manager,
    struct wl_surface *surface,
    struct wl_seat *seat);
void swl_zwp_keyboard_shortcuts_inhibitor_v1_destroy(
    struct zwp_keyboard_shortcuts_inhibitor_v1 *inhibitor);

struct wl_region *swl_compositor_create_region(struct wl_compositor *compositor);
void swl_region_add(
    struct wl_region *region,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height);
void swl_region_subtract(
    struct wl_region *region,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height);
void swl_region_destroy(struct wl_region *region);

/* ------------------------------------------------------------------ */
/*  XDG request wrappers                                              */
/* ------------------------------------------------------------------ */

void swl_xdg_toplevel_set_title(struct xdg_toplevel *xdg_toplevel, const char *title);
void swl_xdg_toplevel_set_app_id(struct xdg_toplevel *xdg_toplevel, const char *app_id);
void swl_xdg_toplevel_show_window_menu(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial,
    int32_t x,
    int32_t y);
void swl_xdg_toplevel_move(
    struct xdg_toplevel *xdg_toplevel, struct wl_seat *seat, uint32_t serial);
void swl_xdg_toplevel_resize(
    struct xdg_toplevel *xdg_toplevel,
    struct wl_seat *seat,
    uint32_t serial,
    uint32_t edges);
void swl_xdg_toplevel_set_max_size(
    struct xdg_toplevel *xdg_toplevel, int32_t width, int32_t height);
void swl_xdg_toplevel_set_min_size(
    struct xdg_toplevel *xdg_toplevel, int32_t width, int32_t height);
void swl_xdg_toplevel_set_maximized(struct xdg_toplevel *xdg_toplevel);
void swl_xdg_toplevel_unset_maximized(struct xdg_toplevel *xdg_toplevel);
void swl_xdg_toplevel_set_fullscreen(
    struct xdg_toplevel *xdg_toplevel, struct wl_output *output);
void swl_xdg_toplevel_unset_fullscreen(struct xdg_toplevel *xdg_toplevel);
void swl_xdg_toplevel_set_minimized(struct xdg_toplevel *xdg_toplevel);
void swl_xdg_positioner_set_size(
    struct xdg_positioner *positioner, int32_t width, int32_t height);
void swl_xdg_positioner_set_anchor_rect(
    struct xdg_positioner *positioner,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height);
void swl_xdg_positioner_set_anchor(
    struct xdg_positioner *positioner, uint32_t anchor);
void swl_xdg_positioner_set_gravity(
    struct xdg_positioner *positioner, uint32_t gravity);
void swl_xdg_positioner_set_constraint_adjustment(
    struct xdg_positioner *positioner, uint32_t constraint_adjustment);
void swl_xdg_positioner_set_offset(
    struct xdg_positioner *positioner, int32_t x, int32_t y);
void swl_xdg_popup_grab(
    struct xdg_popup *popup, struct wl_seat *seat, uint32_t serial);

/* ------------------------------------------------------------------ */
/*  XDG decoration request wrappers                                   */
/* ------------------------------------------------------------------ */

uint32_t swl_zxdg_toplevel_decoration_v1_mode_client_side(void);
uint32_t swl_zxdg_toplevel_decoration_v1_mode_server_side(void);

/* ------------------------------------------------------------------ */
/*  XDG output request wrappers                                       */
/* ------------------------------------------------------------------ */

/* ------------------------------------------------------------------ */
/*  Scale and viewport request wrappers                               */
/* ------------------------------------------------------------------ */

void swl_wp_viewport_set_destination(
    struct wp_viewport *viewport,
    int32_t width,
    int32_t height);

/* ------------------------------------------------------------------ */
/*  Cursor-shape request wrappers                                     */
/* ------------------------------------------------------------------ */

struct wp_cursor_shape_device_v1 *swl_wp_cursor_shape_manager_v1_get_pointer(
    struct wp_cursor_shape_manager_v1 *manager,
    struct wl_pointer *pointer);
void swl_wp_cursor_shape_device_v1_set_shape(
    struct wp_cursor_shape_device_v1 *device,
    uint32_t serial,
    uint32_t shape);

/* ------------------------------------------------------------------ */
/*  Linux DRM syncobj request wrappers                                */
/* ------------------------------------------------------------------ */

struct wp_linux_drm_syncobj_surface_v1 *
swl_wp_linux_drm_syncobj_manager_v1_get_surface(
    struct wp_linux_drm_syncobj_manager_v1 *manager,
    struct wl_surface *surface);
struct wp_linux_drm_syncobj_timeline_v1 *
swl_wp_linux_drm_syncobj_manager_v1_import_timeline(
    struct wp_linux_drm_syncobj_manager_v1 *manager,
    int32_t fd);
void swl_wp_linux_drm_syncobj_surface_v1_set_acquire_point(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface,
    struct wp_linux_drm_syncobj_timeline_v1 *timeline,
    uint32_t point_hi,
    uint32_t point_lo);
void swl_wp_linux_drm_syncobj_surface_v1_set_release_point(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface,
    struct wp_linux_drm_syncobj_timeline_v1 *timeline,
    uint32_t point_hi,
    uint32_t point_lo);

/* ------------------------------------------------------------------ */
/*  FIFO request wrappers                                             */
/* ------------------------------------------------------------------ */

struct wp_fifo_v1 *swl_wp_fifo_manager_v1_get_fifo(
    struct wp_fifo_manager_v1 *manager,
    struct wl_surface *surface);
void swl_wp_fifo_v1_set_barrier(struct wp_fifo_v1 *fifo);
void swl_wp_fifo_v1_wait_barrier(struct wp_fifo_v1 *fifo);

/* ------------------------------------------------------------------ */
/*  Commit-timing request wrappers                                    */
/* ------------------------------------------------------------------ */

struct wp_commit_timer_v1 *swl_wp_commit_timing_manager_v1_get_timer(
    struct wp_commit_timing_manager_v1 *manager,
    struct wl_surface *surface);
void swl_wp_commit_timer_v1_set_timestamp(
    struct wp_commit_timer_v1 *timer,
    uint32_t tv_sec_hi,
    uint32_t tv_sec_lo,
    uint32_t tv_nsec);

/* ------------------------------------------------------------------ */
/*  Surface metadata request wrappers                                 */
/* ------------------------------------------------------------------ */

struct wp_content_type_v1 *swl_wp_content_type_manager_v1_get_surface_content_type(
    struct wp_content_type_manager_v1 *manager,
    struct wl_surface *surface);
void swl_wp_content_type_v1_set_content_type(
    struct wp_content_type_v1 *content_type,
    uint32_t value);

struct wp_alpha_modifier_surface_v1 *swl_wp_alpha_modifier_v1_get_surface(
    struct wp_alpha_modifier_v1 *manager,
    struct wl_surface *surface);
void swl_wp_alpha_modifier_surface_v1_set_multiplier(
    struct wp_alpha_modifier_surface_v1 *surface,
    uint32_t factor);

struct wp_tearing_control_v1 *
swl_wp_tearing_control_manager_v1_get_tearing_control(
    struct wp_tearing_control_manager_v1 *manager,
    struct wl_surface *surface);
void swl_wp_tearing_control_v1_set_presentation_hint(
    struct wp_tearing_control_v1 *tearing_control,
    uint32_t hint);

struct wp_color_representation_surface_v1 *
swl_wp_color_representation_manager_v1_get_surface(
    struct wp_color_representation_manager_v1 *manager,
    struct wl_surface *surface);
void swl_wp_color_representation_surface_v1_set_alpha_mode(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t alpha_mode);
void swl_wp_color_representation_surface_v1_set_coefficients_and_range(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t coefficients,
    uint32_t range);
void swl_wp_color_representation_surface_v1_set_chroma_location(
    struct wp_color_representation_surface_v1 *surface,
    uint32_t chroma_location);

struct wp_color_management_surface_v1 *swl_wp_color_manager_v1_get_surface(
    struct wp_color_manager_v1 *manager,
    struct wl_surface *surface);
struct wp_color_management_surface_feedback_v1 *
swl_wp_color_manager_v1_get_surface_feedback(
    struct wp_color_manager_v1 *manager,
    struct wl_surface *surface);
struct wp_image_description_v1 *swl_wp_color_manager_v1_get_image_description(
    struct wp_color_manager_v1 *manager,
    struct wp_image_description_reference_v1 *reference);
void swl_wp_color_management_surface_v1_set_image_description(
    struct wp_color_management_surface_v1 *surface,
    struct wp_image_description_v1 *image_description,
    uint32_t render_intent);
void swl_wp_color_management_surface_v1_unset_image_description(
    struct wp_color_management_surface_v1 *surface);
struct wp_image_description_v1 *
swl_wp_color_management_surface_feedback_v1_get_preferred(
    struct wp_color_management_surface_feedback_v1 *feedback);

/* ------------------------------------------------------------------ */
/*  Presentation-time request wrappers                                */
/* ------------------------------------------------------------------ */

struct wp_presentation_feedback *swl_wp_presentation_feedback(
    struct wp_presentation *presentation,
    struct wl_surface *surface);

struct zwlr_output_configuration_v1 *
swl_zwlr_output_manager_v1_create_configuration(
    struct zwlr_output_manager_v1 *manager,
    uint32_t serial);
void swl_zwlr_output_manager_v1_stop(struct zwlr_output_manager_v1 *manager);
void swl_zwlr_output_manager_v1_destroy(struct zwlr_output_manager_v1 *manager);
void swl_zwlr_output_head_v1_destroy(struct zwlr_output_head_v1 *head);
void swl_zwlr_output_head_v1_release(struct zwlr_output_head_v1 *head);
void swl_zwlr_output_mode_v1_destroy(struct zwlr_output_mode_v1 *mode);
void swl_zwlr_output_mode_v1_release(struct zwlr_output_mode_v1 *mode);
struct zwlr_output_configuration_head_v1 *
swl_zwlr_output_configuration_v1_enable_head(
    struct zwlr_output_configuration_v1 *configuration,
    struct zwlr_output_head_v1 *head);
void swl_zwlr_output_configuration_v1_disable_head(
    struct zwlr_output_configuration_v1 *configuration,
    struct zwlr_output_head_v1 *head);
void swl_zwlr_output_configuration_v1_apply(
    struct zwlr_output_configuration_v1 *configuration);
void swl_zwlr_output_configuration_v1_test(
    struct zwlr_output_configuration_v1 *configuration);
void swl_zwlr_output_configuration_v1_destroy(
    struct zwlr_output_configuration_v1 *configuration);
void swl_zwlr_output_configuration_head_v1_set_mode(
    struct zwlr_output_configuration_head_v1 *head,
    struct zwlr_output_mode_v1 *mode);
void swl_zwlr_output_configuration_head_v1_set_custom_mode(
    struct zwlr_output_configuration_head_v1 *head,
    int32_t width,
    int32_t height,
    int32_t refresh);
void swl_zwlr_output_configuration_head_v1_set_position(
    struct zwlr_output_configuration_head_v1 *head,
    int32_t x,
    int32_t y);
void swl_zwlr_output_configuration_head_v1_set_transform(
    struct zwlr_output_configuration_head_v1 *head,
    int32_t transform);
void swl_zwlr_output_configuration_head_v1_set_scale(
    struct zwlr_output_configuration_head_v1 *head,
    int32_t scale);
void swl_zwlr_output_configuration_head_v1_destroy(
    struct zwlr_output_configuration_head_v1 *head);

/* ------------------------------------------------------------------ */
/*  Linux dmabuf request wrappers                                     */
/* ------------------------------------------------------------------ */

struct zwp_linux_dmabuf_feedback_v1 *
swl_zwp_linux_dmabuf_v1_get_default_feedback(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf);
struct zwp_linux_dmabuf_feedback_v1 *
swl_zwp_linux_dmabuf_v1_get_surface_feedback(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf,
    struct wl_surface *surface);
struct zwp_linux_buffer_params_v1 *
swl_zwp_linux_dmabuf_v1_create_params(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf);
void swl_zwp_linux_buffer_params_v1_add(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t fd,
    uint32_t plane_idx,
    uint32_t offset,
    uint32_t stride,
    uint32_t modifier_hi,
    uint32_t modifier_lo);
void swl_zwp_linux_buffer_params_v1_create(
    struct zwp_linux_buffer_params_v1 *params,
    int32_t width,
    int32_t height,
    uint32_t format,
    uint32_t flags);

/* ------------------------------------------------------------------ */
/*  Destroy / release wrappers                                        */
/* ------------------------------------------------------------------ */

void swl_registry_destroy(struct wl_registry *registry);
void swl_callback_destroy(struct wl_callback *callback);
void swl_compositor_destroy(struct wl_compositor *compositor);
void swl_subcompositor_destroy(struct wl_subcompositor *subcompositor);
void swl_shm_destroy(struct wl_shm *shm);
void swl_output_destroy(struct wl_output *output);
void swl_buffer_destroy(struct wl_buffer *buffer);
void swl_surface_destroy(struct wl_surface *surface);
void swl_subsurface_destroy(struct wl_subsurface *subsurface);
void swl_shm_pool_destroy(struct wl_shm_pool *pool);
void swl_seat_destroy(struct wl_seat *seat);
void swl_data_offer_destroy(struct wl_data_offer *offer);
void swl_data_source_destroy(struct wl_data_source *source);
void swl_data_device_destroy(struct wl_data_device *device);
void swl_data_device_release(struct wl_data_device *device);
void swl_data_device_manager_destroy(struct wl_data_device_manager *manager);
void swl_primary_selection_offer_destroy(
    struct zwp_primary_selection_offer_v1 *offer);
void swl_primary_selection_source_destroy(
    struct zwp_primary_selection_source_v1 *source);
void swl_primary_selection_device_destroy(
    struct zwp_primary_selection_device_v1 *device);
void swl_primary_selection_device_manager_destroy(
    struct zwp_primary_selection_device_manager_v1 *manager);
void swl_text_input_v3_destroy(struct zwp_text_input_v3 *text_input);
void swl_text_input_manager_v3_destroy(
    struct zwp_text_input_manager_v3 *manager);
void swl_xdg_toplevel_destroy(struct xdg_toplevel *xdg_toplevel);
void swl_xdg_positioner_destroy(struct xdg_positioner *positioner);
void swl_xdg_popup_destroy(struct xdg_popup *popup);
void swl_wp_viewport_destroy(struct wp_viewport *viewport);
void swl_wp_viewporter_destroy(struct wp_viewporter *viewporter);
void swl_wp_fractional_scale_v1_destroy(struct wp_fractional_scale_v1 *fractional_scale);
void swl_wp_fractional_scale_manager_v1_destroy(
    struct wp_fractional_scale_manager_v1 *manager);
void swl_wp_cursor_shape_device_v1_destroy(
    struct wp_cursor_shape_device_v1 *device);
void swl_wp_cursor_shape_manager_v1_destroy(
    struct wp_cursor_shape_manager_v1 *manager);
void swl_xdg_activation_v1_destroy(struct xdg_activation_v1 *activation);
void swl_xdg_activation_token_v1_destroy(
    struct xdg_activation_token_v1 *token);
void swl_xdg_toplevel_icon_manager_v1_destroy(
    struct xdg_toplevel_icon_manager_v1 *manager);
void swl_xdg_toplevel_icon_v1_destroy(
    struct xdg_toplevel_icon_v1 *icon);
void swl_zwp_idle_inhibit_manager_v1_destroy(
    struct zwp_idle_inhibit_manager_v1 *manager);
void swl_zwp_idle_inhibitor_v1_destroy(
    struct zwp_idle_inhibitor_v1 *inhibitor);
void swl_xdg_system_bell_v1_destroy(struct xdg_system_bell_v1 *bell);
void swl_wp_linux_drm_syncobj_surface_v1_destroy(
    struct wp_linux_drm_syncobj_surface_v1 *syncobj_surface);
void swl_wp_linux_drm_syncobj_timeline_v1_destroy(
    struct wp_linux_drm_syncobj_timeline_v1 *timeline);
void swl_wp_linux_drm_syncobj_manager_v1_destroy(
    struct wp_linux_drm_syncobj_manager_v1 *manager);
void swl_wp_fifo_v1_destroy(struct wp_fifo_v1 *fifo);
void swl_wp_fifo_manager_v1_destroy(struct wp_fifo_manager_v1 *manager);
void swl_wp_commit_timer_v1_destroy(struct wp_commit_timer_v1 *timer);
void swl_wp_commit_timing_manager_v1_destroy(
    struct wp_commit_timing_manager_v1 *manager);
void swl_wp_content_type_v1_destroy(struct wp_content_type_v1 *content_type);
void swl_wp_content_type_manager_v1_destroy(
    struct wp_content_type_manager_v1 *manager);
void swl_wp_alpha_modifier_surface_v1_destroy(
    struct wp_alpha_modifier_surface_v1 *surface);
void swl_wp_alpha_modifier_v1_destroy(struct wp_alpha_modifier_v1 *manager);
void swl_wp_tearing_control_v1_destroy(
    struct wp_tearing_control_v1 *tearing_control);
void swl_wp_tearing_control_manager_v1_destroy(
    struct wp_tearing_control_manager_v1 *manager);
void swl_wp_color_representation_surface_v1_destroy(
    struct wp_color_representation_surface_v1 *surface);
void swl_wp_color_representation_manager_v1_destroy(
    struct wp_color_representation_manager_v1 *manager);
void swl_wp_color_management_surface_v1_destroy(
    struct wp_color_management_surface_v1 *surface);
void swl_wp_color_management_surface_feedback_v1_destroy(
    struct wp_color_management_surface_feedback_v1 *feedback);
void swl_wp_image_description_v1_destroy(
    struct wp_image_description_v1 *image_description);
void swl_wp_color_manager_v1_destroy(struct wp_color_manager_v1 *manager);
void swl_wp_presentation_destroy(struct wp_presentation *presentation);
void swl_wp_presentation_feedback_destroy(
    struct wp_presentation_feedback *feedback);
/* ------------------------------------------------------------------ */
/*  Display wrappers                                                  */
/* ------------------------------------------------------------------ */

struct swl_protocol_error_details {
    int32_t     code;
    uint32_t    object_id;
    const char *interface_name;
};

struct wl_registry *swl_display_get_registry(struct wl_display *display);
struct wl_callback *swl_display_sync(struct wl_display *display);

struct wl_event_queue *swl_display_create_event_queue(struct wl_display *display);
void swl_event_queue_destroy(struct wl_event_queue *queue);
struct wl_display *swl_display_create_wrapper(struct wl_display *display);
void swl_display_wrapper_set_queue(
    struct wl_display *display_wrapper,
    struct wl_event_queue *queue);
void swl_display_wrapper_destroy(struct wl_display *display_wrapper);
int swl_display_dispatch_event_queue_pending(
    struct wl_display *display,
    struct wl_event_queue *queue);
int swl_display_prepare_read_event_queue(
    struct wl_display *display,
    struct wl_event_queue *queue);

uint32_t swl_proxy_get_version(void *proxy);
uint32_t swl_proxy_get_id(void *proxy);
struct wl_event_queue *swl_proxy_get_queue_raw(void *proxy);

int swl_display_get_protocol_error_details(
    struct wl_display *display, struct swl_protocol_error_details *details);

#include "generated/shims/listener-bridges.h"

#ifdef SWL_ENABLE_TESTING
/* ------------------------------------------------------------------ */
/*  Test-only scale shim contracts                                    */
/* ------------------------------------------------------------------ */

struct swl_test_surface_preferred_buffer_scale_record {
    int32_t            call_count;
    void              *data;
    struct wl_surface *surface;
    int32_t            factor;
};

struct swl_test_surface_output_record {
    int32_t            call_count;
    void              *data;
    struct wl_surface *surface;
    struct wl_output  *output;
};

enum swl_test_core_request_kind {
    SWL_TEST_CORE_REQUEST_NONE = 0,
    SWL_TEST_CORE_SHM_CREATE_POOL = 1,
    SWL_TEST_CORE_SHM_POOL_CREATE_BUFFER = 2,
    SWL_TEST_CORE_SURFACE_ATTACH = 3,
    SWL_TEST_CORE_SURFACE_DAMAGE = 4,
    SWL_TEST_CORE_SURFACE_DAMAGE_BUFFER = 5,
    SWL_TEST_CORE_SURFACE_COMMIT = 6,
    SWL_TEST_CORE_BUFFER_DESTROY = 7,
    SWL_TEST_CORE_SURFACE_DESTROY = 8,
    SWL_TEST_CORE_SHM_POOL_DESTROY = 9,
    SWL_TEST_CORE_SHM_DESTROY = 10,
    SWL_TEST_CORE_SURFACE_SET_OPAQUE_REGION = 11,
    SWL_TEST_CORE_SURFACE_SET_INPUT_REGION = 12,
    SWL_TEST_CORE_SUBCOMPOSITOR_GET_SUBSURFACE = 13,
    SWL_TEST_CORE_SUBCOMPOSITOR_DESTROY = 14,
    SWL_TEST_CORE_SUBSURFACE_SET_POSITION = 15,
    SWL_TEST_CORE_SUBSURFACE_PLACE_ABOVE = 16,
    SWL_TEST_CORE_SUBSURFACE_PLACE_BELOW = 17,
    SWL_TEST_CORE_SUBSURFACE_SET_SYNC = 18,
    SWL_TEST_CORE_SUBSURFACE_SET_DESYNC = 19,
    SWL_TEST_CORE_SUBSURFACE_DESTROY = 20,
};

enum swl_test_metadata_request_kind {
    SWL_TEST_METADATA_REQUEST_NONE = 0,
    SWL_TEST_METADATA_CONTENT_TYPE_GET_SURFACE = 1,
    SWL_TEST_METADATA_CONTENT_TYPE_SET = 2,
    SWL_TEST_METADATA_COLOR_REPRESENTATION_GET_SURFACE = 3,
    SWL_TEST_METADATA_COLOR_REPRESENTATION_SET_ALPHA_MODE = 4,
    SWL_TEST_METADATA_COLOR_REPRESENTATION_SET_COEFFICIENTS_AND_RANGE = 5,
    SWL_TEST_METADATA_COLOR_REPRESENTATION_SET_CHROMA_LOCATION = 6,
    SWL_TEST_METADATA_COLOR_MANAGER_GET_IMAGE_DESCRIPTION = 7,
    SWL_TEST_METADATA_COLOR_SURFACE_SET_IMAGE_DESCRIPTION = 8,
    SWL_TEST_METADATA_COLOR_SURFACE_UNSET_IMAGE_DESCRIPTION = 9,
    SWL_TEST_METADATA_ALPHA_MODIFIER_GET_SURFACE = 10,
    SWL_TEST_METADATA_ALPHA_MODIFIER_SET_MULTIPLIER = 11,
    SWL_TEST_METADATA_TEARING_CONTROL_GET_SURFACE = 12,
    SWL_TEST_METADATA_TEARING_CONTROL_SET_PRESENTATION_HINT = 13,
    SWL_TEST_METADATA_COLOR_MANAGER_GET_SURFACE = 14,
    SWL_TEST_METADATA_COLOR_MANAGER_GET_SURFACE_FEEDBACK = 15,
    SWL_TEST_METADATA_COLOR_FEEDBACK_GET_PREFERRED = 16,
};

enum swl_test_metadata_destroy_kind {
    SWL_TEST_METADATA_DESTROY_NONE = 0,
    SWL_TEST_METADATA_DESTROY_CONTENT_TYPE = 1,
    SWL_TEST_METADATA_DESTROY_CONTENT_TYPE_MANAGER = 2,
    SWL_TEST_METADATA_DESTROY_COLOR_REPRESENTATION_SURFACE = 3,
    SWL_TEST_METADATA_DESTROY_COLOR_REPRESENTATION_MANAGER = 4,
    SWL_TEST_METADATA_DESTROY_COLOR_MANAGER = 5,
    SWL_TEST_METADATA_DESTROY_IMAGE_DESCRIPTION = 6,
    SWL_TEST_METADATA_DESTROY_ALPHA_MODIFIER_SURFACE = 7,
    SWL_TEST_METADATA_DESTROY_ALPHA_MODIFIER_MANAGER = 8,
    SWL_TEST_METADATA_DESTROY_TEARING_CONTROL = 9,
    SWL_TEST_METADATA_DESTROY_TEARING_CONTROL_MANAGER = 10,
    SWL_TEST_METADATA_DESTROY_COLOR_MANAGEMENT_SURFACE = 11,
    SWL_TEST_METADATA_DESTROY_COLOR_MANAGEMENT_SURFACE_FEEDBACK = 12,
};

enum swl_test_output_destroy_kind {
    SWL_TEST_OUTPUT_DESTROY_NONE = 0,
    SWL_TEST_OUTPUT_HEAD_RELEASE = 1,
    SWL_TEST_OUTPUT_MODE_RELEASE = 2,
    SWL_TEST_OUTPUT_MANAGER_STOP = 3,
    SWL_TEST_OUTPUT_MANAGER_DESTROY = 4,
    SWL_TEST_OUTPUT_HEAD_DESTROY = 5,
    SWL_TEST_OUTPUT_MODE_DESTROY = 6,
};

enum swl_test_output_request_kind {
    SWL_TEST_OUTPUT_REQUEST_NONE = 0,
    SWL_TEST_OUTPUT_MANAGER_CREATE_CONFIGURATION = 1,
    SWL_TEST_OUTPUT_CONFIGURATION_ENABLE_HEAD = 2,
    SWL_TEST_OUTPUT_CONFIGURATION_DISABLE_HEAD = 3,
    SWL_TEST_OUTPUT_CONFIGURATION_APPLY = 4,
    SWL_TEST_OUTPUT_CONFIGURATION_TEST = 5,
    SWL_TEST_OUTPUT_CONFIGURATION_DESTROY = 6,
    SWL_TEST_OUTPUT_CONFIGURATION_HEAD_SET_MODE = 7,
    SWL_TEST_OUTPUT_CONFIGURATION_HEAD_SET_CUSTOM_MODE = 8,
    SWL_TEST_OUTPUT_CONFIGURATION_HEAD_SET_POSITION = 9,
    SWL_TEST_OUTPUT_CONFIGURATION_HEAD_SET_TRANSFORM = 10,
    SWL_TEST_OUTPUT_CONFIGURATION_HEAD_SET_SCALE = 11,
    SWL_TEST_OUTPUT_CONFIGURATION_HEAD_DESTROY = 12,
};

struct swl_test_output_destroy_record {
    int32_t                           call_count;
    enum swl_test_output_destroy_kind kind;
    void                             *object;
};

struct swl_test_output_request_record {
    int32_t                           call_count;
    enum swl_test_output_request_kind kind;
    void                             *object;
    void                             *configuration;
    void                             *configuration_head;
    void                             *head;
    void                             *mode;
    uint32_t                          serial;
    int32_t                           x;
    int32_t                           y;
    int32_t                           width;
    int32_t                           height;
    int32_t                           refresh;
    int32_t                           transform;
    int32_t                           scale;
};

struct swl_test_core_request_record {
    int32_t                         call_count;
    enum swl_test_core_request_kind kind;
    void                           *object;
    struct wl_buffer               *buffer;
    struct wl_region               *region;
    struct wl_surface              *surface;
    struct wl_surface              *parent;
    struct wl_surface              *sibling;
    struct wl_subsurface           *subsurface;
    int32_t                         fd;
    int32_t                         size;
    int32_t                         offset;
    int32_t                         width;
    int32_t                         height;
    int32_t                         stride;
    uint32_t                        format;
    int32_t                         x;
    int32_t                         y;
    uint32_t                        latest_sequence;
    uint32_t                        attach_sequence;
    uint32_t                        damage_sequence;
    uint32_t                        commit_sequence;
    uint32_t                        buffer_destroy_sequence;
    uint32_t                        surface_destroy_sequence;
    uint32_t                        shm_pool_destroy_sequence;
    uint32_t                        opaque_region_sequence;
    uint32_t                        input_region_sequence;
};

struct swl_test_metadata_request_record {
    int32_t                             call_count;
    enum swl_test_metadata_request_kind kind;
    void                               *object;
    void                               *surface;
    void                               *reference;
    void                               *image_description;
    uint32_t                            value;
    uint32_t                            coefficients;
    uint32_t                            range;
    uint32_t                            render_intent;
};

struct swl_test_metadata_destroy_record {
    int32_t                             call_count;
    enum swl_test_metadata_destroy_kind kind;
    void                               *object;
};

struct swl_test_metadata_listener_record {
    int32_t call_count;
    void   *object;
};

struct swl_test_fractional_preferred_scale_record {
    int32_t                        call_count;
    void                          *data;
    struct wp_fractional_scale_v1 *fractional_scale;
    uint32_t                       scale;
};

struct swl_test_viewport_destination_record {
    int32_t             call_count;
    struct wp_viewport *viewport;
    int32_t             width;
    int32_t             height;
};

enum swl_test_scale_destroy_kind {
    SWL_TEST_SCALE_DESTROY_NONE = 0,
    SWL_TEST_SCALE_DESTROY_VIEWPORT = 1,
    SWL_TEST_SCALE_DESTROY_VIEWPORTER = 2,
    SWL_TEST_SCALE_DESTROY_FRACTIONAL_SCALE = 3,
    SWL_TEST_SCALE_DESTROY_FRACTIONAL_SCALE_MANAGER = 4,
};

struct swl_test_scale_destroy_record {
    int32_t                          call_count;
    enum swl_test_scale_destroy_kind kind;
    void                            *object;
};

struct swl_test_data_offer_offer_record {
    int32_t               call_count;
    void                 *data;
    struct wl_data_offer *offer;
    const char           *mime_type;
};

struct swl_test_data_offer_action_record {
    int32_t               call_count;
    void                 *data;
    struct wl_data_offer *offer;
    uint32_t              action;
};

struct swl_test_data_source_send_record {
    int32_t                call_count;
    void                  *data;
    struct wl_data_source *source;
    const char            *mime_type;
    int32_t                fd;
};

struct swl_test_data_source_lifecycle_record {
    int32_t                call_count;
    void                  *data;
    struct wl_data_source *source;
};

struct swl_test_data_source_action_record {
    int32_t                call_count;
    void                  *data;
    struct wl_data_source *source;
    uint32_t               action;
};

struct swl_test_data_device_offer_record {
    int32_t                call_count;
    void                  *data;
    struct wl_data_device *device;
    struct wl_data_offer  *offer;
};

struct swl_test_data_device_enter_record {
    int32_t                call_count;
    void                  *data;
    struct wl_data_device *device;
    uint32_t               serial;
    struct wl_surface     *surface;
    wl_fixed_t             x;
    wl_fixed_t             y;
    struct wl_data_offer  *offer;
};

struct swl_test_data_device_motion_record {
    int32_t                call_count;
    void                  *data;
    struct wl_data_device *device;
    uint32_t               time;
    wl_fixed_t             x;
    wl_fixed_t             y;
};

struct swl_test_data_device_lifecycle_record {
    int32_t                call_count;
    void                  *data;
    struct wl_data_device *device;
};

struct swl_test_primary_selection_offer_offer_record {
    int32_t                                call_count;
    void                                  *data;
    struct zwp_primary_selection_offer_v1 *offer;
    const char                            *mime_type;
};

struct swl_test_primary_selection_source_send_record {
    int32_t                                 call_count;
    void                                   *data;
    struct zwp_primary_selection_source_v1 *source;
    const char                             *mime_type;
    int32_t                                 fd;
};

struct swl_test_primary_selection_source_lifecycle_record {
    int32_t                                 call_count;
    void                                   *data;
    struct zwp_primary_selection_source_v1 *source;
};

struct swl_test_primary_selection_device_offer_record {
    int32_t                                call_count;
    void                                  *data;
    struct zwp_primary_selection_device_v1 *device;
    struct zwp_primary_selection_offer_v1 *offer;
};

enum swl_test_primary_selection_request_kind {
    SWL_TEST_PRIMARY_SELECTION_REQUEST_NONE = 0,
    SWL_TEST_PRIMARY_SELECTION_SOURCE_OFFER = 1,
    SWL_TEST_PRIMARY_SELECTION_OFFER_RECEIVE = 2,
    SWL_TEST_PRIMARY_SELECTION_DEVICE_SET_SELECTION = 3,
};

struct swl_test_primary_selection_request_record {
    int32_t                                      call_count;
    enum swl_test_primary_selection_request_kind kind;
    void                                        *object;
    void                                        *source;
    const char                                  *mime_type;
    uint32_t                                     serial;
    int32_t                                      fd;
};

enum swl_test_primary_selection_destroy_kind {
    SWL_TEST_PRIMARY_SELECTION_DESTROY_NONE = 0,
    SWL_TEST_PRIMARY_SELECTION_DESTROY_OFFER = 1,
    SWL_TEST_PRIMARY_SELECTION_DESTROY_SOURCE = 2,
    SWL_TEST_PRIMARY_SELECTION_DESTROY_DEVICE = 3,
    SWL_TEST_PRIMARY_SELECTION_DESTROY_MANAGER = 4,
};

struct swl_test_primary_selection_destroy_record {
    int32_t                                     call_count;
    enum swl_test_primary_selection_destroy_kind kind;
    void                                       *object;
};

enum swl_test_data_request_kind {
    SWL_TEST_DATA_REQUEST_NONE = 0,
    SWL_TEST_DATA_SOURCE_OFFER = 1,
    SWL_TEST_DATA_SOURCE_SET_ACTIONS = 2,
    SWL_TEST_DATA_OFFER_ACCEPT = 3,
    SWL_TEST_DATA_OFFER_RECEIVE = 4,
    SWL_TEST_DATA_OFFER_FINISH = 5,
    SWL_TEST_DATA_OFFER_SET_ACTIONS = 6,
    SWL_TEST_DATA_DEVICE_SET_SELECTION = 7,
    SWL_TEST_DATA_DEVICE_START_DRAG = 8,
};

struct swl_test_data_request_record {
    int32_t                         call_count;
    enum swl_test_data_request_kind kind;
    void                           *object;
    void                           *source;
    void                           *origin;
    void                           *icon;
    const char                     *mime_type;
    uint32_t                        serial;
    uint32_t                        actions;
    uint32_t                        preferred_action;
    int32_t                         fd;
};

enum swl_test_text_input_request_kind {
    SWL_TEST_TEXT_INPUT_REQUEST_NONE = 0,
    SWL_TEST_TEXT_INPUT_MANAGER_GET_TEXT_INPUT = 1,
    SWL_TEST_TEXT_INPUT_ENABLE = 2,
    SWL_TEST_TEXT_INPUT_DISABLE = 3,
    SWL_TEST_TEXT_INPUT_SET_SURROUNDING_TEXT = 4,
    SWL_TEST_TEXT_INPUT_SET_TEXT_CHANGE_CAUSE = 5,
    SWL_TEST_TEXT_INPUT_SET_CONTENT_TYPE = 6,
    SWL_TEST_TEXT_INPUT_SET_CURSOR_RECTANGLE = 7,
    SWL_TEST_TEXT_INPUT_COMMIT = 8,
    SWL_TEST_TEXT_INPUT_SHOW_INPUT_PANEL = 9,
    SWL_TEST_TEXT_INPUT_HIDE_INPUT_PANEL = 10,
};

struct swl_test_text_input_request_record {
    int32_t                               call_count;
    enum swl_test_text_input_request_kind kind;
    void                                 *object;
    struct wl_seat                       *seat;
    const char                           *text;
    int32_t                               cursor;
    int32_t                               anchor;
    uint32_t                              cause;
    uint32_t                              hint;
    uint32_t                              purpose;
    int32_t                               x;
    int32_t                               y;
    int32_t                               width;
    int32_t                               height;
};

enum swl_test_text_input_destroy_kind {
    SWL_TEST_TEXT_INPUT_DESTROY_NONE = 0,
    SWL_TEST_TEXT_INPUT_DESTROY_TEXT_INPUT = 1,
    SWL_TEST_TEXT_INPUT_DESTROY_MANAGER = 2,
};

struct swl_test_text_input_destroy_record {
    int32_t                               call_count;
    enum swl_test_text_input_destroy_kind kind;
    void                                 *object;
};

enum swl_test_text_input_listener_kind {
    SWL_TEST_TEXT_INPUT_LISTENER_NONE = 0,
    SWL_TEST_TEXT_INPUT_LISTENER_ENTER = 1,
    SWL_TEST_TEXT_INPUT_LISTENER_LEAVE = 2,
    SWL_TEST_TEXT_INPUT_LISTENER_PREEDIT_STRING = 3,
    SWL_TEST_TEXT_INPUT_LISTENER_COMMIT_STRING = 4,
    SWL_TEST_TEXT_INPUT_LISTENER_DELETE_SURROUNDING_TEXT = 5,
    SWL_TEST_TEXT_INPUT_LISTENER_DONE = 6,
    SWL_TEST_TEXT_INPUT_LISTENER_ACTION = 7,
    SWL_TEST_TEXT_INPUT_LISTENER_LANGUAGE = 8,
    SWL_TEST_TEXT_INPUT_LISTENER_PREEDIT_HINT = 9,
};

struct swl_test_text_input_listener_record {
    int32_t                                call_count;
    enum swl_test_text_input_listener_kind kind;
    void                                  *data;
    struct zwp_text_input_v3              *text_input;
    struct wl_surface                     *surface;
    const char                            *text;
    int32_t                                cursor_begin;
    int32_t                                cursor_end;
    uint32_t                               before_length;
    uint32_t                               after_length;
    uint32_t                               serial;
    uint32_t                               action;
    uint32_t                               start;
    uint32_t                               end;
    uint32_t                               hint;
};

enum swl_test_cursor_shape_request_kind {
    SWL_TEST_CURSOR_SHAPE_REQUEST_NONE = 0,
    SWL_TEST_CURSOR_SHAPE_GET_POINTER = 1,
    SWL_TEST_CURSOR_SHAPE_SET_SHAPE = 2,
};

struct swl_test_cursor_shape_request_record {
    int32_t                                  call_count;
    enum swl_test_cursor_shape_request_kind kind;
    void                                    *object;
    struct wl_pointer                       *pointer;
    uint32_t                                 serial;
    uint32_t                                 shape;
};

enum swl_test_cursor_shape_destroy_kind {
    SWL_TEST_CURSOR_SHAPE_DESTROY_NONE = 0,
    SWL_TEST_CURSOR_SHAPE_DESTROY_DEVICE = 1,
    SWL_TEST_CURSOR_SHAPE_DESTROY_MANAGER = 2,
};

struct swl_test_cursor_shape_destroy_record {
    int32_t                                  call_count;
    enum swl_test_cursor_shape_destroy_kind kind;
    void                                    *object;
};

enum swl_test_activation_request_kind {
    SWL_TEST_ACTIVATION_REQUEST_NONE = 0,
    SWL_TEST_ACTIVATION_GET_TOKEN = 1,
    SWL_TEST_ACTIVATION_ACTIVATE = 2,
    SWL_TEST_ACTIVATION_TOKEN_SET_SERIAL = 3,
    SWL_TEST_ACTIVATION_TOKEN_SET_APP_ID = 4,
    SWL_TEST_ACTIVATION_TOKEN_SET_SURFACE = 5,
    SWL_TEST_ACTIVATION_TOKEN_COMMIT = 6,
};

struct swl_test_activation_request_record {
    int32_t                                call_count;
    enum swl_test_activation_request_kind kind;
    void                                  *object;
    void                                  *seat;
    void                                  *surface;
    uint32_t                               serial;
    const char                            *text;
};

enum swl_test_activation_destroy_kind {
    SWL_TEST_ACTIVATION_DESTROY_NONE = 0,
    SWL_TEST_ACTIVATION_DESTROY_MANAGER = 1,
    SWL_TEST_ACTIVATION_DESTROY_TOKEN = 2,
};

struct swl_test_activation_destroy_record {
    int32_t                                call_count;
    enum swl_test_activation_destroy_kind kind;
    void                                  *object;
};

enum swl_test_activation_listener_kind {
    SWL_TEST_ACTIVATION_LISTENER_NONE = 0,
    SWL_TEST_ACTIVATION_LISTENER_DONE = 1,
};

struct swl_test_activation_listener_record {
    int32_t                                call_count;
    enum swl_test_activation_listener_kind kind;
    void                                  *data;
    void                                  *token;
    const char                            *text;
};

enum swl_test_desktop_request_kind {
    SWL_TEST_DESKTOP_REQUEST_NONE = 0,
    SWL_TEST_DESKTOP_TOPLEVEL_ICON_CREATE_ICON = 1,
    SWL_TEST_DESKTOP_TOPLEVEL_ICON_SET_ICON = 2,
    SWL_TEST_DESKTOP_TOPLEVEL_ICON_SET_NAME = 3,
    SWL_TEST_DESKTOP_TOPLEVEL_ICON_ADD_BUFFER = 4,
    SWL_TEST_DESKTOP_IDLE_INHIBIT_CREATE_INHIBITOR = 5,
    SWL_TEST_DESKTOP_SYSTEM_BELL_RING = 6,
    SWL_TEST_DESKTOP_DIALOG_GET = 7,
    SWL_TEST_DESKTOP_DIALOG_SET_MODAL = 8,
    SWL_TEST_DESKTOP_DIALOG_UNSET_MODAL = 9,
    SWL_TEST_DESKTOP_TOPLEVEL_DRAG_GET = 10,
    SWL_TEST_DESKTOP_TOPLEVEL_DRAG_ATTACH = 11,
    SWL_TEST_DESKTOP_FOREIGN_TOPLEVEL_LIST_STOP = 12,
};

struct swl_test_desktop_request_record {
    int32_t                            call_count;
    enum swl_test_desktop_request_kind kind;
    void                              *object;
    struct xdg_toplevel               *toplevel;
    struct xdg_toplevel_icon_v1       *icon;
    struct wl_buffer                  *buffer;
    struct wl_surface                 *surface;
    struct xdg_dialog_v1              *dialog;
    struct xdg_toplevel_drag_v1       *drag;
    struct wl_data_source             *data_source;
    struct zwp_idle_inhibitor_v1      *inhibitor;
    int32_t                            x;
    int32_t                            y;
    int32_t                            scale;
    const char                        *text;
};

enum swl_test_desktop_destroy_kind {
    SWL_TEST_DESKTOP_DESTROY_NONE = 0,
    SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_ICON_MANAGER = 1,
    SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_ICON = 2,
    SWL_TEST_DESKTOP_DESTROY_IDLE_INHIBIT_MANAGER = 3,
    SWL_TEST_DESKTOP_DESTROY_IDLE_INHIBITOR = 4,
    SWL_TEST_DESKTOP_DESTROY_SYSTEM_BELL = 5,
    SWL_TEST_DESKTOP_DESTROY_DIALOG_MANAGER = 6,
    SWL_TEST_DESKTOP_DESTROY_DIALOG = 7,
    SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_DRAG_MANAGER = 8,
    SWL_TEST_DESKTOP_DESTROY_TOPLEVEL_DRAG = 9,
    SWL_TEST_DESKTOP_DESTROY_FOREIGN_TOPLEVEL_LIST = 10,
    SWL_TEST_DESKTOP_DESTROY_FOREIGN_TOPLEVEL_HANDLE = 11,
};

struct swl_test_desktop_destroy_record {
    int32_t                            call_count;
    enum swl_test_desktop_destroy_kind kind;
    void                              *object;
};

enum swl_test_pointer_capture_request_kind {
    SWL_TEST_POINTER_CAPTURE_REQUEST_NONE = 0,
    SWL_TEST_POINTER_CAPTURE_GET_RELATIVE_POINTER = 1,
    SWL_TEST_POINTER_CAPTURE_LOCK_POINTER = 2,
    SWL_TEST_POINTER_CAPTURE_CONFINE_POINTER = 3,
    SWL_TEST_POINTER_CAPTURE_LOCK_SET_CURSOR_HINT = 4,
    SWL_TEST_POINTER_CAPTURE_LOCK_SET_REGION = 5,
    SWL_TEST_POINTER_CAPTURE_CONFINE_SET_REGION = 6,
    SWL_TEST_POINTER_CAPTURE_REGION_ADD = 7,
    SWL_TEST_POINTER_CAPTURE_REGION_SUBTRACT = 8,
    SWL_TEST_POINTER_CAPTURE_WARP_POINTER = 9,
    SWL_TEST_POINTER_CAPTURE_GET_SWIPE_GESTURE = 10,
    SWL_TEST_POINTER_CAPTURE_GET_PINCH_GESTURE = 11,
    SWL_TEST_POINTER_CAPTURE_GET_HOLD_GESTURE = 12,
    SWL_TEST_POINTER_CAPTURE_INHIBIT_SHORTCUTS = 13,
};

struct swl_test_pointer_capture_request_record {
    int32_t                                      call_count;
    enum swl_test_pointer_capture_request_kind kind;
    void                                        *object;
    void                                        *surface;
    void                                        *pointer;
    void                                        *seat;
    void                                        *region;
    uint32_t                                     lifetime;
    int32_t                                      x;
    int32_t                                      y;
    int32_t                                      width;
    int32_t                                      height;
    uint32_t                                     serial;
};

enum swl_test_pointer_capture_destroy_kind {
    SWL_TEST_POINTER_CAPTURE_DESTROY_NONE = 0,
    SWL_TEST_POINTER_CAPTURE_DESTROY_RELATIVE_MANAGER = 1,
    SWL_TEST_POINTER_CAPTURE_DESTROY_RELATIVE_POINTER = 2,
    SWL_TEST_POINTER_CAPTURE_DESTROY_CONSTRAINTS = 3,
    SWL_TEST_POINTER_CAPTURE_DESTROY_LOCKED_POINTER = 4,
    SWL_TEST_POINTER_CAPTURE_DESTROY_CONFINED_POINTER = 5,
    SWL_TEST_POINTER_CAPTURE_DESTROY_REGION = 6,
    SWL_TEST_POINTER_CAPTURE_DESTROY_POINTER_WARP = 7,
    SWL_TEST_POINTER_CAPTURE_DESTROY_GESTURES = 8,
    SWL_TEST_POINTER_CAPTURE_DESTROY_SWIPE_GESTURE = 9,
    SWL_TEST_POINTER_CAPTURE_DESTROY_PINCH_GESTURE = 10,
    SWL_TEST_POINTER_CAPTURE_DESTROY_HOLD_GESTURE = 11,
    SWL_TEST_POINTER_CAPTURE_DESTROY_SHORTCUTS_MANAGER = 12,
    SWL_TEST_POINTER_CAPTURE_DESTROY_SHORTCUTS_INHIBITOR = 13,
    SWL_TEST_POINTER_CAPTURE_RELEASE_GESTURES = 14,
};

struct swl_test_pointer_capture_destroy_record {
    int32_t                                      call_count;
    enum swl_test_pointer_capture_destroy_kind kind;
    void                                        *object;
};

enum swl_test_pointer_capture_listener_kind {
    SWL_TEST_POINTER_CAPTURE_LISTENER_NONE = 0,
    SWL_TEST_POINTER_CAPTURE_LISTENER_RELATIVE_MOTION = 1,
    SWL_TEST_POINTER_CAPTURE_LISTENER_LOCKED = 2,
    SWL_TEST_POINTER_CAPTURE_LISTENER_UNLOCKED = 3,
    SWL_TEST_POINTER_CAPTURE_LISTENER_CONFINED = 4,
    SWL_TEST_POINTER_CAPTURE_LISTENER_UNCONFINED = 5,
    SWL_TEST_POINTER_CAPTURE_LISTENER_SHORTCUTS_ACTIVE = 6,
    SWL_TEST_POINTER_CAPTURE_LISTENER_SHORTCUTS_INACTIVE = 7,
};

struct swl_test_pointer_capture_listener_record {
    int32_t                                      call_count;
    enum swl_test_pointer_capture_listener_kind kind;
    void                                        *data;
    void                                        *object;
    uint32_t                                     utime_hi;
    uint32_t                                     utime_lo;
    int32_t                                      dx;
    int32_t                                      dy;
    int32_t                                      dx_unaccel;
    int32_t                                      dy_unaccel;
};

enum swl_test_syncobj_request_kind {
    SWL_TEST_SYNCOBJ_REQUEST_NONE = 0,
    SWL_TEST_SYNCOBJ_GET_SURFACE = 1,
    SWL_TEST_SYNCOBJ_IMPORT_TIMELINE = 2,
    SWL_TEST_SYNCOBJ_SET_ACQUIRE_POINT = 3,
    SWL_TEST_SYNCOBJ_SET_RELEASE_POINT = 4,
};

struct swl_test_syncobj_request_record {
    int32_t                            call_count;
    enum swl_test_syncobj_request_kind kind;
    void                              *object;
    void                              *surface;
    void                              *timeline;
    int32_t                            fd;
    uint32_t                           point_hi;
    uint32_t                           point_lo;
};

enum swl_test_syncobj_destroy_kind {
    SWL_TEST_SYNCOBJ_DESTROY_NONE = 0,
    SWL_TEST_SYNCOBJ_DESTROY_SURFACE = 1,
    SWL_TEST_SYNCOBJ_DESTROY_TIMELINE = 2,
    SWL_TEST_SYNCOBJ_DESTROY_MANAGER = 3,
};

struct swl_test_syncobj_destroy_record {
    int32_t                             call_count;
    enum swl_test_syncobj_destroy_kind  kind;
    void                               *object;
};

enum swl_test_fifo_request_kind {
    SWL_TEST_FIFO_REQUEST_NONE = 0,
    SWL_TEST_FIFO_GET_FIFO = 1,
    SWL_TEST_FIFO_SET_BARRIER = 2,
    SWL_TEST_FIFO_WAIT_BARRIER = 3,
};

struct swl_test_fifo_request_record {
    int32_t                         call_count;
    enum swl_test_fifo_request_kind kind;
    void                           *object;
    void                           *surface;
};

enum swl_test_fifo_destroy_kind {
    SWL_TEST_FIFO_DESTROY_NONE = 0,
    SWL_TEST_FIFO_DESTROY_FIFO = 1,
    SWL_TEST_FIFO_DESTROY_MANAGER = 2,
};

struct swl_test_fifo_destroy_record {
    int32_t                         call_count;
    enum swl_test_fifo_destroy_kind kind;
    void                           *object;
};

enum swl_test_commit_timing_request_kind {
    SWL_TEST_COMMIT_TIMING_REQUEST_NONE = 0,
    SWL_TEST_COMMIT_TIMING_GET_TIMER = 1,
    SWL_TEST_COMMIT_TIMING_SET_TIMESTAMP = 2,
};

struct swl_test_commit_timing_request_record {
    int32_t                                  call_count;
    enum swl_test_commit_timing_request_kind kind;
    void                                    *object;
    void                                    *surface;
    uint32_t                                 tv_sec_hi;
    uint32_t                                 tv_sec_lo;
    uint32_t                                 tv_nsec;
};

enum swl_test_commit_timing_destroy_kind {
    SWL_TEST_COMMIT_TIMING_DESTROY_NONE = 0,
    SWL_TEST_COMMIT_TIMING_DESTROY_TIMER = 1,
    SWL_TEST_COMMIT_TIMING_DESTROY_MANAGER = 2,
};

struct swl_test_commit_timing_destroy_record {
    int32_t                                 call_count;
    enum swl_test_commit_timing_destroy_kind kind;
    void                                   *object;
};

enum swl_test_presentation_request_kind {
    SWL_TEST_PRESENTATION_REQUEST_NONE = 0,
    SWL_TEST_PRESENTATION_FEEDBACK = 1,
    SWL_TEST_PRESENTATION_DESTROY = 2,
    SWL_TEST_PRESENTATION_FEEDBACK_DESTROY = 3,
};

struct swl_test_presentation_request_record {
    int32_t                                 call_count;
    enum swl_test_presentation_request_kind kind;
    void                                   *object;
    void                                   *surface;
    void                                   *feedback;
};

struct swl_test_presentation_listener_record {
    int32_t call_count;
    void   *object;
};

enum swl_test_dmabuf_request_kind {
    SWL_TEST_DMABUF_REQUEST_NONE = 0,
    SWL_TEST_DMABUF_GET_DEFAULT_FEEDBACK = 1,
    SWL_TEST_DMABUF_GET_SURFACE_FEEDBACK = 2,
    SWL_TEST_DMABUF_CREATE_PARAMS = 3,
    SWL_TEST_DMABUF_BUFFER_PARAMS_ADD = 4,
    SWL_TEST_DMABUF_BUFFER_PARAMS_CREATE = 5,
};

struct swl_test_dmabuf_request_record {
    int32_t                           call_count;
    enum swl_test_dmabuf_request_kind kind;
    void                             *object;
    void                             *surface;
    int32_t                           fd;
    uint32_t                          plane_idx;
    uint32_t                          offset;
    uint32_t                          stride;
    uint32_t                          modifier_hi;
    uint32_t                          modifier_lo;
    int32_t                           width;
    int32_t                           height;
    uint32_t                          format;
    uint32_t                          flags;
};

enum swl_test_data_destroy_kind {
    SWL_TEST_DATA_DESTROY_NONE = 0,
    SWL_TEST_DATA_DESTROY_OFFER = 1,
    SWL_TEST_DATA_DESTROY_SOURCE = 2,
    SWL_TEST_DATA_DESTROY_DEVICE = 3,
    SWL_TEST_DATA_DESTROY_MANAGER = 4,
    SWL_TEST_DATA_DESTROY_DEVICE_LEGACY = 5,
};

struct swl_test_data_destroy_record {
    int32_t                         call_count;
    enum swl_test_data_destroy_kind kind;
    void                           *object;
};

struct swl_test_xdg_popup_configure_record {
    int32_t           call_count;
    void             *data;
    struct xdg_popup *popup;
    int32_t           x;
    int32_t           y;
    int32_t           width;
    int32_t           height;
};

struct swl_test_xdg_popup_done_record {
    int32_t           call_count;
    void             *data;
    struct xdg_popup *popup;
};

struct swl_test_xdg_popup_repositioned_record {
    int32_t           call_count;
    void             *data;
    struct xdg_popup *popup;
    uint32_t          token;
};

enum swl_test_xdg_toplevel_request_kind {
    SWL_TEST_XDG_TOPLEVEL_REQUEST_NONE = 0,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_SHOW_WINDOW_MENU = 1,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_MOVE = 2,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_RESIZE = 3,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MAX_SIZE = 4,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MIN_SIZE = 5,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MAXIMIZED = 6,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_UNSET_MAXIMIZED = 7,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_FULLSCREEN = 8,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_UNSET_FULLSCREEN = 9,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_MINIMIZED = 10,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_TITLE = 11,
    SWL_TEST_XDG_TOPLEVEL_REQUEST_SET_APP_ID = 12,
};

struct swl_test_xdg_toplevel_request_record {
    int32_t                                  call_count;
    enum swl_test_xdg_toplevel_request_kind kind;
    struct xdg_toplevel                    *toplevel;
    struct wl_seat                         *seat;
    struct wl_output                       *output;
    uint32_t                                serial;
    int32_t                                 x;
    int32_t                                 y;
    int32_t                                 width;
    int32_t                                 height;
    uint32_t                                value;
    const char                             *text;
};

enum swl_test_xdg_positioner_request_kind {
    SWL_TEST_XDG_POSITIONER_REQUEST_NONE = 0,
    SWL_TEST_XDG_POSITIONER_REQUEST_SIZE = 1,
    SWL_TEST_XDG_POSITIONER_REQUEST_ANCHOR_RECT = 2,
    SWL_TEST_XDG_POSITIONER_REQUEST_ANCHOR = 3,
    SWL_TEST_XDG_POSITIONER_REQUEST_GRAVITY = 4,
    SWL_TEST_XDG_POSITIONER_REQUEST_CONSTRAINT_ADJUSTMENT = 5,
    SWL_TEST_XDG_POSITIONER_REQUEST_OFFSET = 6,
};

struct swl_test_xdg_positioner_request_record {
    int32_t                                    call_count;
    enum swl_test_xdg_positioner_request_kind kind;
    struct xdg_positioner                    *positioner;
    int32_t                                    x;
    int32_t                                    y;
    int32_t                                    width;
    int32_t                                    height;
    uint32_t                                   value;
};

struct swl_test_xdg_popup_grab_record {
    int32_t           call_count;
    struct xdg_popup *popup;
    struct wl_seat   *seat;
    uint32_t          serial;
};

enum swl_test_xdg_destroy_kind {
    SWL_TEST_XDG_DESTROY_NONE = 0,
    SWL_TEST_XDG_DESTROY_POSITIONER = 1,
    SWL_TEST_XDG_DESTROY_POPUP = 2,
    SWL_TEST_XDG_DESTROY_TOPLEVEL = 3,
};

struct swl_test_xdg_destroy_record {
    int32_t                        call_count;
    enum swl_test_xdg_destroy_kind kind;
    void                          *object;
};

int swl_test_surface_listener_emit_preferred_buffer_scale(
    void *data,
    struct wl_surface *surface,
    int32_t factor,
    struct swl_test_surface_preferred_buffer_scale_record *record);

void swl_test_surface_listener_emit_enter(
    void *data,
    struct wl_surface *surface,
    struct wl_output *output,
    struct swl_test_surface_output_record *record);

void swl_test_surface_listener_emit_leave(
    void *data,
    struct wl_surface *surface,
    struct wl_output *output,
    struct swl_test_surface_output_record *record);

void swl_test_fractional_scale_listener_emit_preferred_scale(
    void *data,
    struct wp_fractional_scale_v1 *fractional_scale,
    uint32_t scale,
    struct swl_test_fractional_preferred_scale_record *record);

void swl_test_core_request_recording_begin(void);
void swl_test_core_request_recording_begin_forwarding(void);
void swl_test_core_request_recording_end(void);
struct swl_test_core_request_record swl_test_core_request_record(void);

void swl_test_metadata_request_recording_begin(void);
void swl_test_metadata_request_recording_end(void);
struct swl_test_metadata_request_record swl_test_metadata_request_record(void);
struct swl_test_metadata_destroy_record swl_test_metadata_destroy_record(void);
void swl_test_output_request_recording_begin(void);
void swl_test_output_request_recording_end(void);
struct swl_test_output_request_record swl_test_output_request_record(void);
struct swl_test_output_destroy_record swl_test_output_destroy_record(void);
void swl_test_metadata_listener_recording_begin(void);
void swl_test_metadata_listener_recording_end(void);
struct swl_test_metadata_listener_record swl_test_metadata_listener_record(void);
int swl_test_color_representation_listener_emit_supported_alpha_mode(
    uint32_t alpha_mode);
int swl_test_color_representation_listener_emit_supported_coefficients_and_ranges(
    uint32_t coefficients,
    uint32_t range);
int swl_test_color_representation_listener_emit_done(void);
int swl_test_image_description_listener_emit_ready(uint32_t identity);
int swl_test_image_description_listener_emit_ready2(
    uint32_t identity_hi,
    uint32_t identity_lo);
int swl_test_image_description_listener_emit_failed(
    uint32_t cause,
    const char *message);
void swl_test_buffer_listener_recording_begin(void);
void swl_test_buffer_listener_recording_end(void);

void swl_test_scale_request_recording_begin(void);
void swl_test_scale_request_recording_end(void);
struct swl_test_viewport_destination_record
swl_test_scale_viewport_destination_record(void);
struct swl_test_scale_destroy_record swl_test_scale_destroy_record(void);

void swl_test_data_offer_listener_emit_offer(
    void *data,
    struct wl_data_offer *offer,
    const char *mime_type,
    struct swl_test_data_offer_offer_record *record);
void swl_test_data_offer_listener_emit_source_actions(
    void *data,
    struct wl_data_offer *offer,
    uint32_t source_actions,
    struct swl_test_data_offer_action_record *record);
void swl_test_data_offer_listener_emit_action(
    void *data,
    struct wl_data_offer *offer,
    uint32_t action,
    struct swl_test_data_offer_action_record *record);
void swl_test_data_source_listener_emit_target(
    void *data,
    struct wl_data_source *source,
    const char *mime_type,
    struct swl_test_data_source_send_record *record);
void swl_test_data_source_listener_emit_send(
    void *data,
    struct wl_data_source *source,
    const char *mime_type,
    int32_t fd,
    struct swl_test_data_source_send_record *record);
void swl_test_data_source_listener_emit_cancelled(
    void *data,
    struct wl_data_source *source,
    struct swl_test_data_source_lifecycle_record *record);
void swl_test_data_source_listener_emit_dnd_drop_performed(
    void *data,
    struct wl_data_source *source,
    struct swl_test_data_source_lifecycle_record *record);
void swl_test_data_source_listener_emit_dnd_finished(
    void *data,
    struct wl_data_source *source,
    struct swl_test_data_source_lifecycle_record *record);
void swl_test_data_source_listener_emit_action(
    void *data,
    struct wl_data_source *source,
    uint32_t action,
    struct swl_test_data_source_action_record *record);
void swl_test_data_device_listener_emit_data_offer(
    void *data,
    struct wl_data_device *device,
    struct wl_data_offer *offer,
    struct swl_test_data_device_offer_record *record);
void swl_test_data_device_listener_emit_enter(
    void *data,
    struct wl_data_device *device,
    uint32_t serial,
    struct wl_surface *surface,
    wl_fixed_t x,
    wl_fixed_t y,
    struct wl_data_offer *offer,
    struct swl_test_data_device_enter_record *record);
void swl_test_data_device_listener_emit_leave(
    void *data,
    struct wl_data_device *device,
    struct swl_test_data_device_lifecycle_record *record);
void swl_test_data_device_listener_emit_motion(
    void *data,
    struct wl_data_device *device,
    uint32_t time,
    wl_fixed_t x,
    wl_fixed_t y,
    struct swl_test_data_device_motion_record *record);
void swl_test_data_device_listener_emit_drop(
    void *data,
    struct wl_data_device *device,
    struct swl_test_data_device_lifecycle_record *record);
void swl_test_data_device_listener_emit_selection(
    void *data,
    struct wl_data_device *device,
    struct wl_data_offer *offer,
    struct swl_test_data_device_offer_record *record);
void swl_test_data_request_recording_begin(void);
void swl_test_data_request_recording_end(void);
struct swl_test_data_request_record swl_test_data_request_record(void);
struct swl_test_data_destroy_record swl_test_data_destroy_record(void);

void swl_test_text_input_request_recording_begin(void);
void swl_test_text_input_request_recording_end(void);
struct swl_test_text_input_request_record
swl_test_text_input_request_record(void);
struct swl_test_text_input_destroy_record
swl_test_text_input_destroy_record(void);
void swl_test_text_input_listener_emit_enter(
    void *data,
    struct zwp_text_input_v3 *text_input,
    struct wl_surface *surface,
    struct swl_test_text_input_listener_record *record);
void swl_test_text_input_listener_emit_leave(
    void *data,
    struct zwp_text_input_v3 *text_input,
    struct wl_surface *surface,
    struct swl_test_text_input_listener_record *record);
void swl_test_text_input_listener_emit_preedit_string(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *text,
    int32_t cursor_begin,
    int32_t cursor_end,
    struct swl_test_text_input_listener_record *record);
void swl_test_text_input_listener_emit_commit_string(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *text,
    struct swl_test_text_input_listener_record *record);
void swl_test_text_input_listener_emit_delete_surrounding_text(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t before_length,
    uint32_t after_length,
    struct swl_test_text_input_listener_record *record);
void swl_test_text_input_listener_emit_done(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t serial,
    struct swl_test_text_input_listener_record *record);
void swl_test_text_input_listener_emit_action(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t action,
    uint32_t serial,
    struct swl_test_text_input_listener_record *record);
void swl_test_text_input_listener_emit_language(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *language,
    struct swl_test_text_input_listener_record *record);
void swl_test_text_input_listener_emit_preedit_hint(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t start,
    uint32_t end,
    uint32_t hint,
    struct swl_test_text_input_listener_record *record);

void swl_test_cursor_shape_request_recording_begin(void);
void swl_test_cursor_shape_request_recording_end(void);
struct swl_test_cursor_shape_request_record
swl_test_cursor_shape_request_record(void);
struct swl_test_cursor_shape_destroy_record
swl_test_cursor_shape_destroy_record(void);

void swl_test_activation_request_recording_begin(void);
void swl_test_activation_request_recording_end(void);
struct swl_test_activation_request_record swl_test_activation_request_record(void);
struct swl_test_activation_destroy_record swl_test_activation_destroy_record(void);
void swl_test_activation_listener_emit_done(
    void *data,
    struct xdg_activation_token_v1 *token,
    const char *token_value,
    struct swl_test_activation_listener_record *record);

void swl_test_desktop_request_recording_begin(void);
void swl_test_desktop_request_recording_begin_forwarding(void);
void swl_test_desktop_request_recording_end(void);
struct swl_test_desktop_request_record swl_test_desktop_request_record(void);
struct swl_test_desktop_destroy_record swl_test_desktop_destroy_record(void);

void swl_test_pointer_capture_request_recording_begin(void);
void swl_test_pointer_capture_request_recording_end(void);
struct swl_test_pointer_capture_request_record
swl_test_pointer_capture_request_record(void);
struct swl_test_pointer_capture_destroy_record
swl_test_pointer_capture_destroy_record(void);
void swl_test_relative_pointer_listener_emit_relative_motion(
    void *data,
    struct zwp_relative_pointer_v1 *relative_pointer,
    uint32_t utime_hi,
    uint32_t utime_lo,
    int32_t dx,
    int32_t dy,
    int32_t dx_unaccel,
    int32_t dy_unaccel,
    struct swl_test_pointer_capture_listener_record *record);
void swl_test_locked_pointer_listener_emit_locked(
    void *data,
    struct zwp_locked_pointer_v1 *locked_pointer,
    struct swl_test_pointer_capture_listener_record *record);
void swl_test_locked_pointer_listener_emit_unlocked(
    void *data,
    struct zwp_locked_pointer_v1 *locked_pointer,
    struct swl_test_pointer_capture_listener_record *record);
void swl_test_confined_pointer_listener_emit_confined(
    void *data,
    struct zwp_confined_pointer_v1 *confined_pointer,
    struct swl_test_pointer_capture_listener_record *record);
void swl_test_confined_pointer_listener_emit_unconfined(
    void *data,
    struct zwp_confined_pointer_v1 *confined_pointer,
    struct swl_test_pointer_capture_listener_record *record);
void swl_test_keyboard_shortcuts_inhibitor_listener_emit_active(
    void *data,
    struct zwp_keyboard_shortcuts_inhibitor_v1 *inhibitor,
    struct swl_test_pointer_capture_listener_record *record);
void swl_test_keyboard_shortcuts_inhibitor_listener_emit_inactive(
    void *data,
    struct zwp_keyboard_shortcuts_inhibitor_v1 *inhibitor,
    struct swl_test_pointer_capture_listener_record *record);
void swl_test_keyboard_shortcuts_inhibitor_listener_set_add_result(int result);

void swl_test_syncobj_request_recording_begin(void);
void swl_test_syncobj_request_recording_end(void);
void swl_test_syncobj_import_timeline_set_failure(int should_fail);
struct swl_test_syncobj_request_record swl_test_syncobj_request_record(void);
struct swl_test_syncobj_destroy_record swl_test_syncobj_destroy_record(void);

void swl_test_fifo_request_recording_begin(void);
void swl_test_fifo_request_recording_end(void);
struct swl_test_fifo_request_record swl_test_fifo_request_record(void);
struct swl_test_fifo_destroy_record swl_test_fifo_destroy_record(void);

void swl_test_commit_timing_request_recording_begin(void);
void swl_test_commit_timing_request_recording_end(void);
struct swl_test_commit_timing_request_record
swl_test_commit_timing_request_record(void);
struct swl_test_commit_timing_destroy_record
swl_test_commit_timing_destroy_record(void);

void swl_test_presentation_request_recording_begin(void);
void swl_test_presentation_request_recording_end(void);
struct swl_test_presentation_request_record
swl_test_presentation_request_record(void);

void swl_test_presentation_listener_recording_begin(void);
void swl_test_presentation_listener_recording_end(void);
struct swl_test_presentation_listener_record
swl_test_presentation_listener_record(void);
int swl_test_presentation_feedback_listener_emit_sync_output(
    struct wl_output *output);
int swl_test_presentation_feedback_listener_emit_presented(
    uint32_t tv_sec_hi,
    uint32_t tv_sec_lo,
    uint32_t tv_nsec,
    uint32_t refresh,
    uint32_t seq_hi,
    uint32_t seq_lo,
    uint32_t flags);
int swl_test_presentation_feedback_listener_emit_discarded(void);

void swl_test_dmabuf_request_recording_begin(void);
void swl_test_dmabuf_request_recording_end(void);
struct swl_test_dmabuf_request_record swl_test_dmabuf_request_record(void);

void swl_test_primary_selection_offer_listener_emit_offer(
    void *data,
    struct zwp_primary_selection_offer_v1 *offer,
    const char *mime_type,
    struct swl_test_primary_selection_offer_offer_record *record);
void swl_test_primary_selection_source_listener_emit_send(
    void *data,
    struct zwp_primary_selection_source_v1 *source,
    const char *mime_type,
    int32_t fd,
    struct swl_test_primary_selection_source_send_record *record);
void swl_test_primary_selection_source_listener_emit_cancelled(
    void *data,
    struct zwp_primary_selection_source_v1 *source,
    struct swl_test_primary_selection_source_lifecycle_record *record);
void swl_test_primary_selection_device_listener_emit_data_offer(
    void *data,
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_offer_v1 *offer,
    struct swl_test_primary_selection_device_offer_record *record);
void swl_test_primary_selection_device_listener_emit_selection(
    void *data,
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_offer_v1 *offer,
    struct swl_test_primary_selection_device_offer_record *record);
void swl_test_primary_selection_request_recording_begin(void);
void swl_test_primary_selection_request_recording_end(void);
struct swl_test_primary_selection_request_record
swl_test_primary_selection_request_record(void);
struct swl_test_primary_selection_destroy_record
swl_test_primary_selection_destroy_record(void);

void swl_test_xdg_popup_listener_emit_configure(
    void *data,
    struct xdg_popup *popup,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height,
    struct swl_test_xdg_popup_configure_record *record);
void swl_test_xdg_popup_listener_emit_done(
    void *data,
    struct xdg_popup *popup,
    struct swl_test_xdg_popup_done_record *record);
void swl_test_xdg_popup_listener_emit_repositioned(
    void *data,
    struct xdg_popup *popup,
    uint32_t token,
    struct swl_test_xdg_popup_repositioned_record *record);

void swl_test_xdg_request_recording_begin(void);
void swl_test_xdg_request_recording_end(void);
struct swl_test_xdg_positioner_request_record
swl_test_xdg_positioner_request_record(void);
struct swl_test_xdg_toplevel_request_record
swl_test_xdg_toplevel_request_record(void);
struct swl_test_xdg_popup_grab_record swl_test_xdg_popup_grab_record(void);
struct swl_test_xdg_destroy_record swl_test_xdg_destroy_record(void);
#endif

#ifdef __cplusplus
}
#endif
