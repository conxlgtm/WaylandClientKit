import CWaylandClientSystem

enum WaylandSmokeCheck {
    static func verify() {
        _ = wl_display_connect
        _ = wl_display_disconnect
        _ = wl_display_roundtrip
    }
}