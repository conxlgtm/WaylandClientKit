import CWaylandProtocols

enum ShimSmokeCheck {
    static func verify() {
        verifyDisplayShims()
        verifyRegistryShims()
        verifyCoreObjectShims()
        verifyXDGShims()
        verifyDestroyShims()
        verifyListenerShims()
    }

    private static func verifyDisplayShims() {
        _ = unsafe swl_display_get_registry
        _ = unsafe swl_display_sync
        _ = unsafe swl_display_create_event_queue
        _ = unsafe swl_event_queue_destroy
        _ = unsafe swl_display_create_wrapper
        _ = unsafe swl_display_wrapper_set_queue
        _ = unsafe swl_display_wrapper_destroy
        _ = unsafe swl_display_dispatch_event_queue_pending
        _ = unsafe swl_display_prepare_read_event_queue
        _ = unsafe swl_display_get_protocol_error_details
    }

    private static func verifyRegistryShims() {
        _ = unsafe swl_registry_bind_wl_compositor
        _ = unsafe swl_registry_bind_wl_shm
        _ = unsafe swl_registry_bind_wl_output
        _ = unsafe swl_registry_bind_xdg_wm_base
        _ = unsafe swl_registry_bind_zxdg_decoration_manager_v1
        _ = unsafe swl_registry_bind_zxdg_output_manager_v1
        _ = unsafe swl_registry_bind_wp_viewporter
        _ = unsafe swl_registry_bind_wp_presentation
        _ = unsafe swl_registry_bind_wp_fractional_scale_manager_v1
        _ = unsafe swl_registry_bind_wp_cursor_shape_manager_v1
        _ = unsafe swl_registry_bind_wp_linux_drm_syncobj_manager_v1
        _ = unsafe swl_registry_bind_wp_fifo_manager_v1
        _ = unsafe swl_registry_bind_wp_commit_timing_manager_v1
        _ = unsafe swl_registry_bind_wp_content_type_manager_v1
        _ = unsafe swl_registry_bind_wp_alpha_modifier_v1
        _ = unsafe swl_registry_bind_wp_tearing_control_manager_v1
        _ = unsafe swl_registry_bind_wp_color_representation_manager_v1
        _ = unsafe swl_registry_bind_wp_color_manager_v1
        _ = unsafe swl_registry_bind_wl_seat
        _ = unsafe swl_registry_bind_zwp_text_input_manager_v3
        _ = unsafe swl_registry_bind_zwp_linux_dmabuf_v1
    }

    private static func verifyCoreObjectShims() {
        _ = unsafe swl_compositor_create_surface
        _ = unsafe swl_shm_create_pool
        _ = unsafe swl_shm_pool_create_buffer
        _ = unsafe swl_surface_frame
        _ = unsafe swl_seat_get_pointer
        _ = unsafe swl_seat_get_keyboard
        _ = unsafe swl_seat_get_touch
        _ = unsafe swl_surface_attach
        _ = unsafe swl_surface_commit
        _ = unsafe swl_surface_damage_buffer
        _ = unsafe swl_surface_set_buffer_scale
    }

    private static func verifyXDGShims() {
        _ = unsafe swl_xdg_wm_base_get_xdg_surface
        _ = unsafe swl_xdg_surface_get_toplevel
        _ = unsafe swl_xdg_wm_base_pong
        _ = unsafe swl_xdg_surface_ack_configure
        _ = unsafe swl_xdg_toplevel_set_title
        _ = unsafe swl_xdg_toplevel_set_app_id
        _ = unsafe swl_xdg_toplevel_show_window_menu
        _ = unsafe swl_xdg_toplevel_move
        _ = unsafe swl_xdg_toplevel_resize
        _ = unsafe swl_xdg_toplevel_set_max_size
        _ = unsafe swl_xdg_toplevel_set_min_size
        _ = unsafe swl_xdg_toplevel_set_maximized
        _ = unsafe swl_xdg_toplevel_unset_maximized
        _ = unsafe swl_xdg_toplevel_set_fullscreen
        _ = unsafe swl_xdg_toplevel_unset_fullscreen
        _ = unsafe swl_xdg_toplevel_set_minimized
        _ = unsafe swl_zxdg_decoration_manager_v1_get_toplevel_decoration
        _ = unsafe swl_zxdg_toplevel_decoration_v1_set_mode
        _ = unsafe swl_zxdg_toplevel_decoration_v1_unset_mode
        _ = swl_zxdg_toplevel_decoration_v1_mode_client_side
        _ = swl_zxdg_toplevel_decoration_v1_mode_server_side
        _ = unsafe swl_zxdg_output_manager_v1_get_xdg_output
        _ = unsafe swl_wp_viewporter_get_viewport
        _ = unsafe swl_wp_viewport_set_destination
        _ = unsafe swl_wp_fractional_scale_manager_v1_get_fractional_scale
        _ = unsafe swl_wp_cursor_shape_manager_v1_get_pointer
        _ = unsafe swl_wp_cursor_shape_device_v1_set_shape
        verifySubmitAndMetadataShims()
        verifyTextInputAndDmabufShims()
    }

    private static func verifySubmitAndMetadataShims() {
        _ = unsafe swl_wp_linux_drm_syncobj_manager_v1_get_surface
        _ = unsafe swl_wp_linux_drm_syncobj_manager_v1_import_timeline
        _ = unsafe swl_wp_linux_drm_syncobj_surface_v1_set_acquire_point
        _ = unsafe swl_wp_linux_drm_syncobj_surface_v1_set_release_point
        _ = unsafe swl_wp_fifo_manager_v1_get_fifo
        _ = unsafe swl_wp_fifo_v1_set_barrier
        _ = unsafe swl_wp_fifo_v1_wait_barrier
        _ = unsafe swl_wp_commit_timing_manager_v1_get_timer
        _ = unsafe swl_wp_commit_timer_v1_set_timestamp
        _ = unsafe swl_wp_content_type_manager_v1_get_surface_content_type
        _ = unsafe swl_wp_content_type_v1_set_content_type
        _ = unsafe swl_wp_alpha_modifier_v1_get_surface
        _ = unsafe swl_wp_alpha_modifier_surface_v1_set_multiplier
        _ = unsafe swl_wp_tearing_control_manager_v1_get_tearing_control
        _ = unsafe swl_wp_tearing_control_v1_set_presentation_hint
        _ = unsafe swl_wp_color_representation_manager_v1_get_surface
        _ = unsafe swl_wp_color_representation_manager_v1_add_listener
        _ = unsafe swl_wp_color_representation_surface_v1_set_alpha_mode
        _ = unsafe swl_wp_color_representation_surface_v1_set_coefficients_and_range
        _ = unsafe swl_wp_color_representation_surface_v1_set_chroma_location
        _ = unsafe swl_wp_color_manager_v1_get_output
        _ = unsafe swl_wp_color_manager_v1_get_surface
        _ = unsafe swl_wp_color_manager_v1_get_surface_feedback
        _ = unsafe swl_wp_color_manager_v1_get_image_description
        _ = unsafe swl_wp_color_manager_v1_add_listener
        _ = unsafe swl_wp_color_management_output_v1_get_image_description
        _ = unsafe swl_wp_color_management_surface_v1_set_image_description
        _ = unsafe swl_wp_color_management_surface_v1_unset_image_description
        _ = unsafe swl_wp_color_management_surface_feedback_v1_get_preferred
    }

    private static func verifyTextInputAndDmabufShims() {
        _ = unsafe swl_text_input_manager_v3_get_text_input
        _ = unsafe swl_text_input_v3_enable
        _ = unsafe swl_text_input_v3_disable
        _ = unsafe swl_text_input_v3_set_surrounding_text
        _ = unsafe swl_text_input_v3_set_text_change_cause
        _ = unsafe swl_text_input_v3_set_content_type
        _ = unsafe swl_text_input_v3_set_cursor_rectangle
        _ = unsafe swl_text_input_v3_commit
        _ = unsafe swl_zwp_linux_dmabuf_v1_get_default_feedback
        _ = unsafe swl_zwp_linux_dmabuf_v1_get_surface_feedback
        _ = unsafe swl_zwp_linux_dmabuf_v1_create_params
        _ = unsafe swl_zwp_linux_buffer_params_v1_add
        _ = unsafe swl_zwp_linux_buffer_params_v1_create
    }

    private static func verifyDestroyShims() {
        _ = unsafe swl_registry_destroy
        _ = unsafe swl_callback_destroy
        _ = unsafe swl_compositor_destroy
        _ = unsafe swl_shm_destroy
        _ = unsafe swl_output_destroy
        _ = unsafe swl_output_release
        _ = unsafe swl_buffer_destroy
        _ = unsafe swl_surface_destroy
        _ = unsafe swl_shm_pool_destroy
        _ = unsafe swl_pointer_release
        _ = unsafe swl_keyboard_release
        _ = unsafe swl_touch_release
        _ = unsafe swl_seat_destroy
        _ = unsafe swl_seat_release
        _ = unsafe swl_xdg_surface_destroy
        _ = unsafe swl_xdg_toplevel_destroy
        _ = unsafe swl_xdg_wm_base_destroy
        _ = unsafe swl_zxdg_toplevel_decoration_v1_destroy
        _ = unsafe swl_zxdg_decoration_manager_v1_destroy
        _ = unsafe swl_zxdg_output_v1_destroy
        _ = unsafe swl_zxdg_output_manager_v1_destroy
        _ = unsafe swl_wp_viewport_destroy
        _ = unsafe swl_wp_viewporter_destroy
        _ = unsafe swl_wp_fractional_scale_v1_destroy
        _ = unsafe swl_wp_fractional_scale_manager_v1_destroy
        _ = unsafe swl_wp_cursor_shape_device_v1_destroy
        _ = unsafe swl_wp_cursor_shape_manager_v1_destroy
        _ = unsafe swl_wp_linux_drm_syncobj_surface_v1_destroy
        _ = unsafe swl_wp_linux_drm_syncobj_timeline_v1_destroy
        _ = unsafe swl_wp_linux_drm_syncobj_manager_v1_destroy
        _ = unsafe swl_wp_fifo_v1_destroy
        _ = unsafe swl_wp_fifo_manager_v1_destroy
        _ = unsafe swl_wp_commit_timer_v1_destroy
        _ = unsafe swl_wp_commit_timing_manager_v1_destroy
        _ = unsafe swl_wp_content_type_v1_destroy
        _ = unsafe swl_wp_content_type_manager_v1_destroy
        _ = unsafe swl_wp_alpha_modifier_surface_v1_destroy
        _ = unsafe swl_wp_alpha_modifier_v1_destroy
        _ = unsafe swl_wp_tearing_control_v1_destroy
        _ = unsafe swl_wp_tearing_control_manager_v1_destroy
        _ = unsafe swl_wp_color_representation_surface_v1_destroy
        _ = unsafe swl_wp_color_representation_manager_v1_destroy
        _ = unsafe swl_wp_color_management_output_v1_destroy
        _ = unsafe swl_wp_color_management_surface_v1_destroy
        _ = unsafe swl_wp_color_management_surface_feedback_v1_destroy
        _ = unsafe swl_wp_image_description_v1_destroy
        _ = unsafe swl_wp_image_description_reference_v1_destroy
        _ = unsafe swl_wp_color_manager_v1_destroy
        _ = unsafe swl_text_input_v3_destroy
        _ = unsafe swl_text_input_manager_v3_destroy
        _ = unsafe swl_wp_presentation_destroy
        _ = unsafe swl_wp_presentation_feedback_destroy
        _ = unsafe swl_zwp_linux_dmabuf_v1_destroy
        _ = unsafe swl_zwp_linux_buffer_params_v1_destroy
        _ = unsafe swl_zwp_linux_dmabuf_feedback_v1_destroy
    }

    private static func verifyListenerShims() {
        _ = unsafe swl_registry_add_listener
        _ = unsafe swl_callback_add_listener
        _ = unsafe swl_buffer_add_listener
        _ = unsafe swl_surface_add_listener
        _ = unsafe swl_output_add_listener
        _ = unsafe swl_xdg_wm_base_add_listener
        _ = unsafe swl_xdg_surface_add_listener
        _ = unsafe swl_xdg_toplevel_add_listener
        _ = unsafe swl_zxdg_toplevel_decoration_v1_add_listener
        _ = unsafe swl_zxdg_output_v1_add_listener
        _ = unsafe swl_wp_fractional_scale_v1_add_listener
        _ = unsafe swl_wp_presentation_add_listener
        _ = unsafe swl_wp_presentation_feedback_add_listener
        _ = unsafe swl_zwp_linux_dmabuf_feedback_v1_add_listener
        _ = unsafe swl_zwp_linux_buffer_params_v1_add_listener
        _ = unsafe swl_text_input_v3_add_listener
        _ = unsafe swl_seat_add_listener
        _ = unsafe swl_pointer_add_listener
        _ = unsafe swl_keyboard_add_listener
        _ = unsafe swl_touch_add_listener
    }
}
