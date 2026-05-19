#pragma once

#ifndef __linux__
#error "SwiftWayland currently supports Linux only."
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
struct zwp_primary_selection_device_manager_v1;
struct zwp_primary_selection_device_v1;
struct zwp_primary_selection_offer_v1;
struct zwp_primary_selection_source_v1;
struct zwp_text_input_manager_v3;
struct zwp_text_input_v3;

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------------------------------------------ */
/*  Registry bind wrappers                                            */
/* ------------------------------------------------------------------ */

struct wl_compositor *swl_registry_bind_wl_compositor(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wl_shm *swl_registry_bind_wl_shm(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wl_output *swl_registry_bind_wl_output(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct xdg_wm_base *swl_registry_bind_xdg_wm_base(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct zxdg_decoration_manager_v1 *swl_registry_bind_zxdg_decoration_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct zxdg_output_manager_v1 *swl_registry_bind_zxdg_output_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_viewporter *swl_registry_bind_wp_viewporter(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_presentation *swl_registry_bind_wp_presentation(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_fractional_scale_manager_v1 *swl_registry_bind_wp_fractional_scale_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_cursor_shape_manager_v1 *swl_registry_bind_wp_cursor_shape_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_linux_drm_syncobj_manager_v1 *
swl_registry_bind_wp_linux_drm_syncobj_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_fifo_manager_v1 *swl_registry_bind_wp_fifo_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_commit_timing_manager_v1 *swl_registry_bind_wp_commit_timing_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_content_type_manager_v1 *swl_registry_bind_wp_content_type_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_alpha_modifier_v1 *swl_registry_bind_wp_alpha_modifier_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_tearing_control_manager_v1 *
swl_registry_bind_wp_tearing_control_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_color_representation_manager_v1 *
swl_registry_bind_wp_color_representation_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wp_color_manager_v1 *swl_registry_bind_wp_color_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wl_seat *swl_registry_bind_wl_seat(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct wl_data_device_manager *swl_registry_bind_wl_data_device_manager(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct zwp_primary_selection_device_manager_v1 *
swl_registry_bind_zwp_primary_selection_device_manager_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct zwp_text_input_manager_v3 *swl_registry_bind_zwp_text_input_manager_v3(
    struct wl_registry *registry, uint32_t name, uint32_t version);

struct zwp_linux_dmabuf_v1 *swl_registry_bind_zwp_linux_dmabuf_v1(
    struct wl_registry *registry, uint32_t name, uint32_t version);

/* ------------------------------------------------------------------ */
/*  Core request wrappers                                             */
/* ------------------------------------------------------------------ */

struct wl_surface *swl_compositor_create_surface(struct wl_compositor *compositor);

struct wl_shm_pool *swl_shm_create_pool(struct wl_shm *shm, int32_t fd, int32_t size);

struct wl_buffer *swl_shm_pool_create_buffer(
    struct wl_shm_pool *pool, int32_t offset, int32_t width,
    int32_t height, int32_t stride, uint32_t format);

struct wl_callback *swl_surface_frame(struct wl_surface *surface);

struct wl_pointer *swl_seat_get_pointer(struct wl_seat *seat);
struct wl_keyboard *swl_seat_get_keyboard(struct wl_seat *seat);
struct wl_touch *swl_seat_get_touch(struct wl_seat *seat);
void swl_pointer_set_cursor(
    struct wl_pointer *pointer,
    uint32_t serial,
    struct wl_surface *surface,
    int32_t hotspot_x,
    int32_t hotspot_y);

void swl_surface_attach(
    struct wl_surface *surface, struct wl_buffer *buffer, int32_t x, int32_t y);
void swl_surface_commit(struct wl_surface *surface);
void swl_surface_damage_buffer(
    struct wl_surface *surface, int32_t x, int32_t y,
    int32_t width, int32_t height);
// for older wl_surface versions
void swl_surface_damage(struct wl_surface *surface, int32_t xd, int32_t y, int32_t width, int32_t height);
void swl_surface_set_buffer_scale(struct wl_surface *surface, int32_t scale);

uint32_t swl_shm_format_xrgb8888(void);
uint32_t swl_shm_format_argb8888(void);

/* ------------------------------------------------------------------ */
/*  Data-device request wrappers                                      */
/* ------------------------------------------------------------------ */

struct wl_data_source *swl_data_device_manager_create_data_source(
    struct wl_data_device_manager *manager);
struct wl_data_device *swl_data_device_manager_get_data_device(
    struct wl_data_device_manager *manager, struct wl_seat *seat);
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

struct zwp_primary_selection_source_v1 *
swl_primary_selection_device_manager_create_source(
    struct zwp_primary_selection_device_manager_v1 *manager);
struct zwp_primary_selection_device_v1 *
swl_primary_selection_device_manager_get_device(
    struct zwp_primary_selection_device_manager_v1 *manager,
    struct wl_seat *seat);
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

/* ------------------------------------------------------------------ */
/*  XDG request wrappers                                              */
/* ------------------------------------------------------------------ */

struct xdg_surface *swl_xdg_wm_base_get_xdg_surface(
    struct xdg_wm_base *wm_base, struct wl_surface *surface);
struct xdg_positioner *swl_xdg_wm_base_create_positioner(
    struct xdg_wm_base *wm_base);

struct xdg_toplevel *swl_xdg_surface_get_toplevel(struct xdg_surface *xdg_surface);
struct xdg_popup *swl_xdg_surface_get_popup(
    struct xdg_surface *xdg_surface,
    struct xdg_surface *parent,
    struct xdg_positioner *positioner);

void swl_xdg_wm_base_pong(struct xdg_wm_base *wm_base, uint32_t serial);
void swl_xdg_surface_ack_configure(struct xdg_surface *xdg_surface, uint32_t serial);
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

struct zxdg_toplevel_decoration_v1 *swl_zxdg_decoration_manager_v1_get_toplevel_decoration(
    struct zxdg_decoration_manager_v1 *manager,
    struct xdg_toplevel *xdg_toplevel);

void swl_zxdg_toplevel_decoration_v1_set_mode(
    struct zxdg_toplevel_decoration_v1 *decoration, uint32_t mode);
void swl_zxdg_toplevel_decoration_v1_unset_mode(
    struct zxdg_toplevel_decoration_v1 *decoration);

uint32_t swl_zxdg_toplevel_decoration_v1_mode_client_side(void);
uint32_t swl_zxdg_toplevel_decoration_v1_mode_server_side(void);

/* ------------------------------------------------------------------ */
/*  XDG output request wrappers                                       */
/* ------------------------------------------------------------------ */

struct zxdg_output_v1 *swl_zxdg_output_manager_v1_get_xdg_output(
    struct zxdg_output_manager_v1 *manager,
    struct wl_output *output);

/* ------------------------------------------------------------------ */
/*  Scale and viewport request wrappers                               */
/* ------------------------------------------------------------------ */

struct wp_viewport *swl_wp_viewporter_get_viewport(
    struct wp_viewporter *viewporter,
    struct wl_surface *surface);
void swl_wp_viewport_set_destination(
    struct wp_viewport *viewport,
    int32_t width,
    int32_t height);

struct wp_fractional_scale_v1 *swl_wp_fractional_scale_manager_v1_get_fractional_scale(
    struct wp_fractional_scale_manager_v1 *manager,
    struct wl_surface *surface);

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

struct wp_color_management_output_v1 *swl_wp_color_manager_v1_get_output(
    struct wp_color_manager_v1 *manager,
    struct wl_output *output);
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
struct wp_image_description_v1 *
swl_wp_color_management_output_v1_get_image_description(
    struct wp_color_management_output_v1 *output);
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
void swl_shm_destroy(struct wl_shm *shm);
void swl_output_destroy(struct wl_output *output);
void swl_output_release(struct wl_output *output);
void swl_buffer_destroy(struct wl_buffer *buffer);
void swl_surface_destroy(struct wl_surface *surface);
void swl_shm_pool_destroy(struct wl_shm_pool *pool);
void swl_pointer_release(struct wl_pointer *pointer);
void swl_keyboard_release(struct wl_keyboard *keyboard);
void swl_touch_release(struct wl_touch *touch);
void swl_seat_destroy(struct wl_seat *seat);
void swl_seat_release(struct wl_seat *seat);
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
void swl_xdg_surface_destroy(struct xdg_surface *xdg_surface);
void swl_xdg_toplevel_destroy(struct xdg_toplevel *xdg_toplevel);
void swl_xdg_positioner_destroy(struct xdg_positioner *positioner);
void swl_xdg_popup_destroy(struct xdg_popup *popup);
void swl_xdg_wm_base_destroy(struct xdg_wm_base *wm_base);
void swl_zxdg_toplevel_decoration_v1_destroy(
    struct zxdg_toplevel_decoration_v1 *decoration);
void swl_zxdg_decoration_manager_v1_destroy(
    struct zxdg_decoration_manager_v1 *manager);
void swl_zxdg_output_v1_destroy(struct zxdg_output_v1 *output);
void swl_zxdg_output_manager_v1_destroy(
    struct zxdg_output_manager_v1 *manager);
void swl_wp_viewport_destroy(struct wp_viewport *viewport);
void swl_wp_viewporter_destroy(struct wp_viewporter *viewporter);
void swl_wp_fractional_scale_v1_destroy(struct wp_fractional_scale_v1 *fractional_scale);
void swl_wp_fractional_scale_manager_v1_destroy(
    struct wp_fractional_scale_manager_v1 *manager);
void swl_wp_cursor_shape_device_v1_destroy(
    struct wp_cursor_shape_device_v1 *device);
void swl_wp_cursor_shape_manager_v1_destroy(
    struct wp_cursor_shape_manager_v1 *manager);
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
void swl_wp_color_management_output_v1_destroy(
    struct wp_color_management_output_v1 *output);
void swl_wp_color_management_surface_v1_destroy(
    struct wp_color_management_surface_v1 *surface);
void swl_wp_color_management_surface_feedback_v1_destroy(
    struct wp_color_management_surface_feedback_v1 *feedback);
void swl_wp_image_description_v1_destroy(
    struct wp_image_description_v1 *image_description);
void swl_wp_image_description_reference_v1_destroy(
    struct wp_image_description_reference_v1 *reference);
void swl_wp_color_manager_v1_destroy(struct wp_color_manager_v1 *manager);
void swl_wp_presentation_destroy(struct wp_presentation *presentation);
void swl_wp_presentation_feedback_destroy(
    struct wp_presentation_feedback *feedback);
void swl_zwp_linux_dmabuf_v1_destroy(
    struct zwp_linux_dmabuf_v1 *linux_dmabuf);
void swl_zwp_linux_buffer_params_v1_destroy(
    struct zwp_linux_buffer_params_v1 *params);
void swl_zwp_linux_dmabuf_feedback_v1_destroy(
    struct zwp_linux_dmabuf_feedback_v1 *feedback);

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

/* ------------------------------------------------------------------ */
/*  Listener callback typedefs                                        */
/* ------------------------------------------------------------------ */

/* Registry */
typedef void (*swl_registry_global_fn)(
    void *data, struct wl_registry *registry, uint32_t name,
    const char *interface, uint32_t version);
typedef void (*swl_registry_global_remove_fn)(
    void *data, struct wl_registry *registry, uint32_t name);

/* Core objects */
typedef void (*swl_callback_done_fn)(
    void *data, struct wl_callback *callback, uint32_t callback_data);
typedef void (*swl_buffer_release_fn)(void *data, struct wl_buffer *buffer);
typedef void (*swl_surface_enter_fn)(
    void *data, struct wl_surface *surface, struct wl_output *output);
typedef void (*swl_surface_leave_fn)(
    void *data, struct wl_surface *surface, struct wl_output *output);
typedef void (*swl_surface_preferred_buffer_scale_fn)(
    void *data, struct wl_surface *surface, int32_t factor);

/* Output */
typedef void (*swl_output_geometry_fn)(
    void *data,
    struct wl_output *output,
    int32_t x,
    int32_t y,
    int32_t physical_width,
    int32_t physical_height,
    int32_t subpixel,
    const char *make,
    const char *model,
    int32_t transform);
typedef void (*swl_output_mode_fn)(
    void *data,
    struct wl_output *output,
    uint32_t flags,
    int32_t width,
    int32_t height,
    int32_t refresh);
typedef void (*swl_output_done_fn)(void *data, struct wl_output *output);
typedef void (*swl_output_scale_fn)(
    void *data, struct wl_output *output, int32_t factor);
typedef void (*swl_output_name_fn)(
    void *data, struct wl_output *output, const char *name);
typedef void (*swl_output_description_fn)(
    void *data, struct wl_output *output, const char *description);

/* XDG output */
typedef void (*swl_zxdg_output_v1_logical_position_fn)(
    void *data, struct zxdg_output_v1 *output, int32_t x, int32_t y);
typedef void (*swl_zxdg_output_v1_logical_size_fn)(
    void *data, struct zxdg_output_v1 *output, int32_t width, int32_t height);
typedef void (*swl_zxdg_output_v1_done_fn)(
    void *data, struct zxdg_output_v1 *output);
typedef void (*swl_zxdg_output_v1_name_fn)(
    void *data, struct zxdg_output_v1 *output, const char *name);
typedef void (*swl_zxdg_output_v1_description_fn)(
    void *data, struct zxdg_output_v1 *output, const char *description);

/* Data device */
typedef void (*swl_data_offer_offer_fn)(
    void *data, struct wl_data_offer *offer, const char *mime_type);
typedef void (*swl_data_offer_source_actions_fn)(
    void *data, struct wl_data_offer *offer, uint32_t source_actions);
typedef void (*swl_data_offer_action_fn)(
    void *data, struct wl_data_offer *offer, uint32_t dnd_action);
typedef void (*swl_data_source_target_fn)(
    void *data, struct wl_data_source *source, const char *mime_type);
typedef void (*swl_data_source_send_fn)(
    void *data, struct wl_data_source *source, const char *mime_type, int32_t fd);
typedef void (*swl_data_source_cancelled_fn)(
    void *data, struct wl_data_source *source);
typedef void (*swl_data_source_dnd_drop_performed_fn)(
    void *data, struct wl_data_source *source);
typedef void (*swl_data_source_dnd_finished_fn)(
    void *data, struct wl_data_source *source);
typedef void (*swl_data_source_action_fn)(
    void *data, struct wl_data_source *source, uint32_t dnd_action);
typedef void (*swl_data_device_data_offer_fn)(
    void *data, struct wl_data_device *device, struct wl_data_offer *offer);
typedef void (*swl_data_device_enter_fn)(
    void *data,
    struct wl_data_device *device,
    uint32_t serial,
    struct wl_surface *surface,
    wl_fixed_t x,
    wl_fixed_t y,
    struct wl_data_offer *offer);
typedef void (*swl_data_device_leave_fn)(void *data, struct wl_data_device *device);
typedef void (*swl_data_device_motion_fn)(
    void *data, struct wl_data_device *device, uint32_t time, wl_fixed_t x, wl_fixed_t y);
typedef void (*swl_data_device_drop_fn)(void *data, struct wl_data_device *device);
typedef void (*swl_data_device_selection_fn)(
    void *data, struct wl_data_device *device, struct wl_data_offer *offer);

/* Primary selection */
typedef void (*swl_primary_selection_offer_offer_fn)(
    void *data,
    struct zwp_primary_selection_offer_v1 *offer,
    const char *mime_type);
typedef void (*swl_primary_selection_source_send_fn)(
    void *data,
    struct zwp_primary_selection_source_v1 *source,
    const char *mime_type,
    int32_t fd);
typedef void (*swl_primary_selection_source_cancelled_fn)(
    void *data,
    struct zwp_primary_selection_source_v1 *source);
typedef void (*swl_primary_selection_device_data_offer_fn)(
    void *data,
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_offer_v1 *offer);
typedef void (*swl_primary_selection_device_selection_fn)(
    void *data,
    struct zwp_primary_selection_device_v1 *device,
    struct zwp_primary_selection_offer_v1 *offer);

/* XDG shell */
typedef void (*swl_xdg_wm_base_ping_fn)(
    void *data, struct xdg_wm_base *wm_base, uint32_t serial);
typedef void (*swl_xdg_surface_configure_fn)(
    void *data, struct xdg_surface *xdg_surface, uint32_t serial);
typedef void (*swl_xdg_toplevel_configure_fn)(
    void *data, struct xdg_toplevel *xdg_toplevel,
    int32_t width, int32_t height, struct wl_array *states);
typedef void (*swl_xdg_toplevel_close_fn)(
    void *data, struct xdg_toplevel *xdg_toplevel);
typedef void (*swl_xdg_toplevel_configure_bounds_fn)(
    void *data, struct xdg_toplevel *xdg_toplevel,
    int32_t width, int32_t height);
typedef void (*swl_xdg_toplevel_wm_capabilities_fn)(
    void *data, struct xdg_toplevel *xdg_toplevel,
    struct wl_array *capabilities);
typedef void (*swl_xdg_popup_configure_fn)(
    void *data,
    struct xdg_popup *popup,
    int32_t x,
    int32_t y,
    int32_t width,
    int32_t height);
typedef void (*swl_xdg_popup_done_fn)(
    void *data, struct xdg_popup *popup);
typedef void (*swl_xdg_popup_repositioned_fn)(
    void *data, struct xdg_popup *popup, uint32_t token);

/* XDG decoration */
typedef void (*swl_zxdg_toplevel_decoration_v1_configure_fn)(
    void *data, struct zxdg_toplevel_decoration_v1 *decoration, uint32_t mode);

/* Fractional scale */
typedef void (*swl_wp_fractional_scale_v1_preferred_scale_fn)(
    void *data, struct wp_fractional_scale_v1 *fractional_scale, uint32_t scale);

/* Presentation time */
typedef void (*swl_wp_presentation_clock_id_fn)(
    void *data, struct wp_presentation *presentation, uint32_t clock_id);
typedef void (*swl_wp_presentation_feedback_sync_output_fn)(
    void *data,
    struct wp_presentation_feedback *feedback,
    struct wl_output *output);
typedef void (*swl_wp_presentation_feedback_presented_fn)(
    void *data,
    struct wp_presentation_feedback *feedback,
    uint32_t tv_sec_hi,
    uint32_t tv_sec_lo,
    uint32_t tv_nsec,
    uint32_t refresh,
    uint32_t seq_hi,
    uint32_t seq_lo,
    uint32_t flags);
typedef void (*swl_wp_presentation_feedback_discarded_fn)(
    void *data, struct wp_presentation_feedback *feedback);

/* Linux dmabuf */
typedef void (*swl_zwp_linux_dmabuf_feedback_done_fn)(
    void *data, struct zwp_linux_dmabuf_feedback_v1 *feedback);
typedef void (*swl_zwp_linux_dmabuf_feedback_format_table_fn)(
    void *data,
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    int32_t fd,
    uint32_t size);
typedef void (*swl_zwp_linux_dmabuf_feedback_main_device_fn)(
    void *data,
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    struct wl_array *device);
typedef void (*swl_zwp_linux_dmabuf_feedback_tranche_done_fn)(
    void *data, struct zwp_linux_dmabuf_feedback_v1 *feedback);
typedef void (*swl_zwp_linux_dmabuf_feedback_tranche_target_device_fn)(
    void *data,
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    struct wl_array *device);
typedef void (*swl_zwp_linux_dmabuf_feedback_tranche_formats_fn)(
    void *data,
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    struct wl_array *indices);
typedef void (*swl_zwp_linux_dmabuf_feedback_tranche_flags_fn)(
    void *data,
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    uint32_t flags);
typedef void (*swl_zwp_linux_buffer_params_created_fn)(
    void *data,
    struct zwp_linux_buffer_params_v1 *params,
    struct wl_buffer *buffer);
typedef void (*swl_zwp_linux_buffer_params_failed_fn)(
    void *data,
    struct zwp_linux_buffer_params_v1 *params);

/* Surface metadata */
typedef void (*swl_wp_color_representation_manager_v1_supported_alpha_mode_fn)(
    void *data,
    struct wp_color_representation_manager_v1 *manager,
    uint32_t alpha_mode);
typedef void (*swl_wp_color_representation_manager_v1_supported_coefficients_and_ranges_fn)(
    void *data,
    struct wp_color_representation_manager_v1 *manager,
    uint32_t coefficients,
    uint32_t range);
typedef void (*swl_wp_color_representation_manager_v1_done_fn)(
    void *data,
    struct wp_color_representation_manager_v1 *manager);
typedef void (*swl_wp_color_manager_v1_supported_intent_fn)(
    void *data,
    struct wp_color_manager_v1 *manager,
    uint32_t render_intent);
typedef void (*swl_wp_color_manager_v1_supported_feature_fn)(
    void *data,
    struct wp_color_manager_v1 *manager,
    uint32_t feature);
typedef void (*swl_wp_color_manager_v1_supported_tf_named_fn)(
    void *data,
    struct wp_color_manager_v1 *manager,
    uint32_t transfer_function);
typedef void (*swl_wp_color_manager_v1_supported_primaries_named_fn)(
    void *data,
    struct wp_color_manager_v1 *manager,
    uint32_t primaries);
typedef void (*swl_wp_color_manager_v1_done_fn)(
    void *data,
    struct wp_color_manager_v1 *manager);

/* Text input */
typedef void (*swl_text_input_v3_enter_fn)(
    void *data, struct zwp_text_input_v3 *text_input, struct wl_surface *surface);
typedef void (*swl_text_input_v3_leave_fn)(
    void *data, struct zwp_text_input_v3 *text_input, struct wl_surface *surface);
typedef void (*swl_text_input_v3_preedit_string_fn)(
    void *data,
    struct zwp_text_input_v3 *text_input,
    const char *text,
    int32_t cursor_begin,
    int32_t cursor_end);
typedef void (*swl_text_input_v3_commit_string_fn)(
    void *data, struct zwp_text_input_v3 *text_input, const char *text);
typedef void (*swl_text_input_v3_delete_surrounding_text_fn)(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t before_length,
    uint32_t after_length);
typedef void (*swl_text_input_v3_done_fn)(
    void *data, struct zwp_text_input_v3 *text_input, uint32_t serial);
typedef void (*swl_text_input_v3_action_fn)(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t action,
    uint32_t serial);
typedef void (*swl_text_input_v3_language_fn)(
    void *data, struct zwp_text_input_v3 *text_input, const char *language);
typedef void (*swl_text_input_v3_preedit_hint_fn)(
    void *data,
    struct zwp_text_input_v3 *text_input,
    uint32_t start,
    uint32_t end,
    uint32_t hint);

/* Seat */
typedef void (*swl_seat_capabilities_fn)(
    void *data, struct wl_seat *seat, uint32_t capabilities);
typedef void (*swl_seat_name_fn)(
    void *data, struct wl_seat *seat, const char *name);

/* Pointer */
typedef void (*swl_pointer_enter_fn)(
    void *data, struct wl_pointer *pointer, uint32_t serial,
    struct wl_surface *surface, wl_fixed_t surface_x, wl_fixed_t surface_y);
typedef void (*swl_pointer_leave_fn)(
    void *data, struct wl_pointer *pointer,
    uint32_t serial, struct wl_surface *surface);
typedef void (*swl_pointer_motion_fn)(
    void *data, struct wl_pointer *pointer,
    uint32_t time, wl_fixed_t surface_x, wl_fixed_t surface_y);
typedef void (*swl_pointer_button_fn)(
    void *data, struct wl_pointer *pointer,
    uint32_t serial, uint32_t time, uint32_t button, uint32_t state);
typedef void (*swl_pointer_axis_fn)(
    void *data, struct wl_pointer *pointer,
    uint32_t time, uint32_t axis, wl_fixed_t value);
typedef void (*swl_pointer_frame_fn)(void *data, struct wl_pointer *pointer);
typedef void (*swl_pointer_axis_source_fn)(
    void *data, struct wl_pointer *pointer, uint32_t axis_source);
typedef void (*swl_pointer_axis_stop_fn)(
    void *data, struct wl_pointer *pointer, uint32_t time, uint32_t axis);
typedef void (*swl_pointer_axis_discrete_fn)(
    void *data, struct wl_pointer *pointer, uint32_t axis, int32_t discrete);
typedef void (*swl_pointer_axis_value120_fn)(
    void *data, struct wl_pointer *pointer, uint32_t axis, int32_t value120);
typedef void (*swl_pointer_axis_relative_direction_fn)(
    void *data, struct wl_pointer *pointer,
    uint32_t axis, uint32_t direction);

/* Keyboard */
typedef void (*swl_keyboard_keymap_fn)(
    void *data, struct wl_keyboard *keyboard,
    uint32_t format, int32_t fd, uint32_t size);
typedef void (*swl_keyboard_enter_fn)(
    void *data, struct wl_keyboard *keyboard,
    uint32_t serial, struct wl_surface *surface, struct wl_array *keys);
typedef void (*swl_keyboard_leave_fn)(
    void *data, struct wl_keyboard *keyboard,
    uint32_t serial, struct wl_surface *surface);
typedef void (*swl_keyboard_key_fn)(
    void *data, struct wl_keyboard *keyboard,
    uint32_t serial, uint32_t time, uint32_t key, uint32_t state);
typedef void (*swl_keyboard_modifiers_fn)(
    void *data, struct wl_keyboard *keyboard, uint32_t serial,
    uint32_t mods_depressed, uint32_t mods_latched,
    uint32_t mods_locked, uint32_t group);
typedef void (*swl_keyboard_repeat_info_fn)(
    void *data, struct wl_keyboard *keyboard, int32_t rate, int32_t delay);

/* Touch */
typedef void (*swl_touch_down_fn)(
    void *data, struct wl_touch *touch, uint32_t serial, uint32_t time,
    struct wl_surface *surface, int32_t id, wl_fixed_t x, wl_fixed_t y);
typedef void (*swl_touch_up_fn)(
    void *data, struct wl_touch *touch,
    uint32_t serial, uint32_t time, int32_t id);
typedef void (*swl_touch_motion_fn)(
    void *data, struct wl_touch *touch,
    uint32_t time, int32_t id, wl_fixed_t x, wl_fixed_t y);
typedef void (*swl_touch_frame_fn)(void *data, struct wl_touch *touch);
typedef void (*swl_touch_cancel_fn)(void *data, struct wl_touch *touch);
typedef void (*swl_touch_shape_fn)(
    void *data, struct wl_touch *touch,
    int32_t id, wl_fixed_t major, wl_fixed_t minor);
typedef void (*swl_touch_orientation_fn)(
    void *data, struct wl_touch *touch, int32_t id, wl_fixed_t orientation);

/* ------------------------------------------------------------------ */
/*  Callback bundle structs                                           */
/* ------------------------------------------------------------------ */

struct swl_registry_listener_callbacks {
    swl_registry_global_fn        global;
    swl_registry_global_remove_fn global_remove;
    void                         *data;
};

struct swl_callback_listener_callbacks {
    swl_callback_done_fn done;
    void                *data;
};

struct swl_buffer_listener_callbacks {
    swl_buffer_release_fn release;
    void                 *data;
};

struct swl_surface_listener_callbacks {
    swl_surface_enter_fn                  enter;
    swl_surface_leave_fn                  leave;
    swl_surface_preferred_buffer_scale_fn preferred_buffer_scale;
    void                                 *data;
};

struct swl_output_listener_callbacks {
    swl_output_geometry_fn    geometry;
    swl_output_mode_fn        mode;
    swl_output_done_fn        done;
    swl_output_scale_fn       scale;
    swl_output_name_fn        name;
    swl_output_description_fn description;
    void                     *data;
};

struct swl_data_offer_listener_callbacks {
    swl_data_offer_offer_fn          offer;
    swl_data_offer_source_actions_fn source_actions;
    swl_data_offer_action_fn         action;
    void                            *data;
};

struct swl_data_source_listener_callbacks {
    swl_data_source_target_fn             target;
    swl_data_source_send_fn               send;
    swl_data_source_cancelled_fn          cancelled;
    swl_data_source_dnd_drop_performed_fn dnd_drop_performed;
    swl_data_source_dnd_finished_fn       dnd_finished;
    swl_data_source_action_fn             action;
    void                                 *data;
};

struct swl_data_device_listener_callbacks {
    swl_data_device_data_offer_fn data_offer;
    swl_data_device_enter_fn      enter;
    swl_data_device_leave_fn      leave;
    swl_data_device_motion_fn     motion;
    swl_data_device_drop_fn       drop;
    swl_data_device_selection_fn  selection;
    void                         *data;
};

struct swl_primary_selection_offer_listener_callbacks {
    swl_primary_selection_offer_offer_fn offer;
    void                               *data;
};

struct swl_primary_selection_source_listener_callbacks {
    swl_primary_selection_source_send_fn      send;
    swl_primary_selection_source_cancelled_fn cancelled;
    void                                     *data;
};

struct swl_primary_selection_device_listener_callbacks {
    swl_primary_selection_device_data_offer_fn data_offer;
    swl_primary_selection_device_selection_fn  selection;
    void                                      *data;
};

struct swl_xdg_wm_base_listener_callbacks {
    swl_xdg_wm_base_ping_fn ping;
    void                    *data;
};

struct swl_xdg_surface_listener_callbacks {
    swl_xdg_surface_configure_fn configure;
    void                        *data;
};

struct swl_xdg_toplevel_listener_callbacks {
    swl_xdg_toplevel_configure_fn        configure;
    swl_xdg_toplevel_close_fn            close;
    swl_xdg_toplevel_configure_bounds_fn configure_bounds;
    swl_xdg_toplevel_wm_capabilities_fn  wm_capabilities;
    void                                *data;
};

struct swl_xdg_popup_listener_callbacks {
    swl_xdg_popup_configure_fn    configure;
    swl_xdg_popup_done_fn         popup_done;
    swl_xdg_popup_repositioned_fn repositioned;
    void                         *data;
};

struct swl_zxdg_toplevel_decoration_v1_listener_callbacks {
    swl_zxdg_toplevel_decoration_v1_configure_fn configure;
    void                                        *data;
};

struct swl_zxdg_output_v1_listener_callbacks {
    swl_zxdg_output_v1_logical_position_fn logical_position;
    swl_zxdg_output_v1_logical_size_fn     logical_size;
    swl_zxdg_output_v1_done_fn             done;
    swl_zxdg_output_v1_name_fn             name;
    swl_zxdg_output_v1_description_fn      description;
    void                                  *data;
};

struct swl_wp_fractional_scale_v1_listener_callbacks {
    swl_wp_fractional_scale_v1_preferred_scale_fn preferred_scale;
    void                                         *data;
};

struct swl_wp_presentation_listener_callbacks {
    swl_wp_presentation_clock_id_fn clock_id;
    void                           *data;
};

struct swl_wp_presentation_feedback_listener_callbacks {
    swl_wp_presentation_feedback_sync_output_fn sync_output;
    swl_wp_presentation_feedback_presented_fn   presented;
    swl_wp_presentation_feedback_discarded_fn   discarded;
    void                                       *data;
};

struct swl_zwp_linux_dmabuf_feedback_listener_callbacks {
    swl_zwp_linux_dmabuf_feedback_done_fn                  done;
    swl_zwp_linux_dmabuf_feedback_format_table_fn          format_table;
    swl_zwp_linux_dmabuf_feedback_main_device_fn           main_device;
    swl_zwp_linux_dmabuf_feedback_tranche_done_fn          tranche_done;
    swl_zwp_linux_dmabuf_feedback_tranche_target_device_fn tranche_target_device;
    swl_zwp_linux_dmabuf_feedback_tranche_formats_fn       tranche_formats;
    swl_zwp_linux_dmabuf_feedback_tranche_flags_fn         tranche_flags;
    void                                                  *data;
};

struct swl_zwp_linux_buffer_params_listener_callbacks {
    swl_zwp_linux_buffer_params_created_fn created;
    swl_zwp_linux_buffer_params_failed_fn  failed;
    void                                  *data;
};

struct swl_wp_color_representation_manager_v1_listener_callbacks {
    swl_wp_color_representation_manager_v1_supported_alpha_mode_fn supported_alpha_mode;
    swl_wp_color_representation_manager_v1_supported_coefficients_and_ranges_fn
        supported_coefficients_and_ranges;
    swl_wp_color_representation_manager_v1_done_fn done;
    void                                          *data;
};

struct swl_wp_color_manager_v1_listener_callbacks {
    swl_wp_color_manager_v1_supported_intent_fn          supported_intent;
    swl_wp_color_manager_v1_supported_feature_fn         supported_feature;
    swl_wp_color_manager_v1_supported_tf_named_fn        supported_tf_named;
    swl_wp_color_manager_v1_supported_primaries_named_fn supported_primaries_named;
    swl_wp_color_manager_v1_done_fn                      done;
    void                                                *data;
};

struct swl_text_input_v3_listener_callbacks {
    swl_text_input_v3_enter_fn                   enter;
    swl_text_input_v3_leave_fn                   leave;
    swl_text_input_v3_preedit_string_fn          preedit_string;
    swl_text_input_v3_commit_string_fn           commit_string;
    swl_text_input_v3_delete_surrounding_text_fn delete_surrounding_text;
    swl_text_input_v3_done_fn                    done;
    swl_text_input_v3_action_fn                  action;
    swl_text_input_v3_language_fn                language;
    swl_text_input_v3_preedit_hint_fn            preedit_hint;
    void                                        *data;
};

struct swl_seat_listener_callbacks {
    swl_seat_capabilities_fn capabilities;
    swl_seat_name_fn         name;
    void                    *data;
};

struct swl_pointer_listener_callbacks {
    swl_pointer_enter_fn                  enter;
    swl_pointer_leave_fn                  leave;
    swl_pointer_motion_fn                 motion;
    swl_pointer_button_fn                 button;
    swl_pointer_axis_fn                   axis;
    swl_pointer_frame_fn                  frame;
    swl_pointer_axis_source_fn            axis_source;
    swl_pointer_axis_stop_fn              axis_stop;
    swl_pointer_axis_discrete_fn          axis_discrete;
    swl_pointer_axis_value120_fn          axis_value120;
    swl_pointer_axis_relative_direction_fn axis_relative_direction;
    void                                  *data;
};

struct swl_keyboard_listener_callbacks {
    swl_keyboard_keymap_fn      keymap;
    swl_keyboard_enter_fn       enter;
    swl_keyboard_leave_fn       leave;
    swl_keyboard_key_fn         key;
    swl_keyboard_modifiers_fn   modifiers;
    swl_keyboard_repeat_info_fn repeat_info;
    void                       *data;
};

struct swl_touch_listener_callbacks {
    swl_touch_down_fn        down;
    swl_touch_up_fn          up;
    swl_touch_motion_fn      motion;
    swl_touch_frame_fn       frame;
    swl_touch_cancel_fn      cancel;
    swl_touch_shape_fn       shape;
    swl_touch_orientation_fn orientation;
    void                    *data;
};

/* ------------------------------------------------------------------ */
/*  Typed listener installers                                         */
/* ------------------------------------------------------------------ */

int swl_registry_add_listener(
    struct wl_registry *registry,
    const struct swl_registry_listener_callbacks *callbacks);

int swl_callback_add_listener(
    struct wl_callback *callback,
    const struct swl_callback_listener_callbacks *callbacks);

int swl_buffer_add_listener(
    struct wl_buffer *buffer,
    const struct swl_buffer_listener_callbacks *callbacks);

int swl_surface_add_listener(
    struct wl_surface *surface,
    const struct swl_surface_listener_callbacks *callbacks);

int swl_output_add_listener(
    struct wl_output *output,
    const struct swl_output_listener_callbacks *callbacks);

int swl_data_offer_add_listener(
    struct wl_data_offer *offer,
    const struct swl_data_offer_listener_callbacks *callbacks);

int swl_data_source_add_listener(
    struct wl_data_source *source,
    const struct swl_data_source_listener_callbacks *callbacks);

int swl_data_device_add_listener(
    struct wl_data_device *device,
    const struct swl_data_device_listener_callbacks *callbacks);

int swl_primary_selection_offer_add_listener(
    struct zwp_primary_selection_offer_v1 *offer,
    const struct swl_primary_selection_offer_listener_callbacks *callbacks);

int swl_primary_selection_source_add_listener(
    struct zwp_primary_selection_source_v1 *source,
    const struct swl_primary_selection_source_listener_callbacks *callbacks);

int swl_primary_selection_device_add_listener(
    struct zwp_primary_selection_device_v1 *device,
    const struct swl_primary_selection_device_listener_callbacks *callbacks);

int swl_xdg_wm_base_add_listener(
    struct xdg_wm_base *wm_base,
    const struct swl_xdg_wm_base_listener_callbacks *callbacks);

int swl_xdg_surface_add_listener(
    struct xdg_surface *xdg_surface,
    const struct swl_xdg_surface_listener_callbacks *callbacks);

int swl_xdg_toplevel_add_listener(
    struct xdg_toplevel *xdg_toplevel,
    const struct swl_xdg_toplevel_listener_callbacks *callbacks);

int swl_xdg_popup_add_listener(
    struct xdg_popup *popup,
    const struct swl_xdg_popup_listener_callbacks *callbacks);

int swl_zxdg_toplevel_decoration_v1_add_listener(
    struct zxdg_toplevel_decoration_v1 *decoration,
    const struct swl_zxdg_toplevel_decoration_v1_listener_callbacks *callbacks);

int swl_zxdg_output_v1_add_listener(
    struct zxdg_output_v1 *output,
    const struct swl_zxdg_output_v1_listener_callbacks *callbacks);

int swl_wp_fractional_scale_v1_add_listener(
    struct wp_fractional_scale_v1 *fractional_scale,
    const struct swl_wp_fractional_scale_v1_listener_callbacks *callbacks);

int swl_wp_presentation_add_listener(
    struct wp_presentation *presentation,
    const struct swl_wp_presentation_listener_callbacks *callbacks);

int swl_wp_presentation_feedback_add_listener(
    struct wp_presentation_feedback *feedback,
    const struct swl_wp_presentation_feedback_listener_callbacks *callbacks);

int swl_zwp_linux_dmabuf_feedback_v1_add_listener(
    struct zwp_linux_dmabuf_feedback_v1 *feedback,
    const struct swl_zwp_linux_dmabuf_feedback_listener_callbacks *callbacks);

int swl_zwp_linux_buffer_params_v1_add_listener(
    struct zwp_linux_buffer_params_v1 *params,
    const struct swl_zwp_linux_buffer_params_listener_callbacks *callbacks);

int swl_wp_color_representation_manager_v1_add_listener(
    struct wp_color_representation_manager_v1 *manager,
    const struct swl_wp_color_representation_manager_v1_listener_callbacks *callbacks);

int swl_wp_color_manager_v1_add_listener(
    struct wp_color_manager_v1 *manager,
    const struct swl_wp_color_manager_v1_listener_callbacks *callbacks);

int swl_text_input_v3_add_listener(
    struct zwp_text_input_v3 *text_input,
    const struct swl_text_input_v3_listener_callbacks *callbacks);

int swl_seat_add_listener(
    struct wl_seat *seat,
    const struct swl_seat_listener_callbacks *callbacks);

int swl_pointer_add_listener(
    struct wl_pointer *pointer,
    const struct swl_pointer_listener_callbacks *callbacks);

int swl_keyboard_add_listener(
    struct wl_keyboard *keyboard,
    const struct swl_keyboard_listener_callbacks *callbacks);

int swl_touch_add_listener(
    struct wl_touch *touch,
    const struct swl_touch_listener_callbacks *callbacks);

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

struct swl_test_core_request_record {
    int32_t                         call_count;
    enum swl_test_core_request_kind kind;
    void                           *object;
    struct wl_buffer               *buffer;
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
void swl_test_core_request_recording_end(void);
struct swl_test_core_request_record swl_test_core_request_record(void);

void swl_test_metadata_request_recording_begin(void);
void swl_test_metadata_request_recording_end(void);
struct swl_test_metadata_request_record swl_test_metadata_request_record(void);
struct swl_test_metadata_destroy_record swl_test_metadata_destroy_record(void);
void swl_test_metadata_listener_recording_begin(void);
void swl_test_metadata_listener_recording_end(void);
struct swl_test_metadata_listener_record swl_test_metadata_listener_record(void);
int swl_test_color_representation_listener_emit_supported_alpha_mode(
    uint32_t alpha_mode);
int swl_test_color_representation_listener_emit_supported_coefficients_and_ranges(
    uint32_t coefficients,
    uint32_t range);
int swl_test_color_representation_listener_emit_done(void);
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
