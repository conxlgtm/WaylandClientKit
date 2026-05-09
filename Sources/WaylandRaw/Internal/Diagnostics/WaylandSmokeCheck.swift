import CWaylandClientSystem

@safe
enum WaylandSmokeCheck {
    static func verify() {
        _ = unsafe wl_display_connect
        _ = unsafe wl_display_disconnect
        _ = unsafe wl_display_roundtrip
        _ = unsafe wl_display_get_fd
        _ = unsafe wl_display_get_error
        _ = unsafe wl_display_flush
        _ = unsafe wl_display_read_events
        _ = unsafe wl_display_cancel_read
    }
}
