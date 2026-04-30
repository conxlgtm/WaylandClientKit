import CWaylandClientSystem

enum WaylandSmokeCheck {
    static func verify() {
        _ = wl_display_connect
        _ = wl_display_disconnect
        _ = wl_display_roundtrip
        _ = wl_display_get_fd
        _ = wl_display_get_error
        _ = wl_display_flush
        _ = wl_display_read_events
        _ = wl_display_cancel_read
    }
}
