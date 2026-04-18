import CWaylandProtocols

enum ShimSmokeCheck {
    static func verify() {
        _ = swl_registry_bind_wl_compositor
        _ = swl_registry_bind_wl_shm
        _ = swl_registry_bind_xdg_wm_base
        _ = swl_registry_bind_wl_seat

        _ = swl_compositor_create_surface
        _ = swl_shm_create_pool
        _ = swl_shm_pool_create_buffer
        _ = swl_surface_frame
        _ = swl_seat_get_pointer
        _ = swl_seat_get_keyboard

        _ = swl_xdg_wm_base_get_xdg_surface
        _ = swl_xdg_surface_get_toplevel
        _ = swl_xdg_wm_base_pong
        _ = swl_xdg_surface_ack_configure
        _ = swl_xdg_toplevel_set_title
        _ = swl_xdg_toplevel_set_app_id

        _ = swl_callback_destroy
        _ = swl_buffer_destroy
        _ = swl_surface_destroy
        _ = swl_shm_pool_destroy
        _ = swl_pointer_release
        _ = swl_keyboard_release
        _ = swl_seat_release
        _ = swl_xdg_surface_destroy
        _ = swl_xdg_toplevel_destroy
        _ = swl_xdg_wm_base_destroy

        _ = swl_registry_add_listener
        _ = swl_callback_add_listener
        _ = swl_buffer_add_listener
        _ = swl_xdg_wm_base_add_listener
        _ = swl_xdg_surface_add_listener
        _ = swl_xdg_toplevel_add_listener
        _ = swl_seat_add_listener
    }
}
