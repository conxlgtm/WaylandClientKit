import CWaylandProtocols

package struct RawXDGTopLevelResizeEdge: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue edgeRawValue: UInt32) {
        rawValue = edgeRawValue
    }

    package static let top = Self(rawValue: 1)
    package static let bottom = Self(rawValue: 2)
    package static let left = Self(rawValue: 4)
    package static let topLeft = Self(rawValue: 5)
    package static let bottomLeft = Self(rawValue: 6)
    package static let right = Self(rawValue: 8)
    package static let topRight = Self(rawValue: 9)
    package static let bottomRight = Self(rawValue: 10)
}

extension RawXDGTopLevel {
    package func showWindowMenu(seat: RawSeat, serial: UInt32, x: Int32, y: Int32) {
        unsafe swl_xdg_toplevel_show_window_menu(pointer, seat.pointer, serial, x, y)
    }

    package func move(seat: RawSeat, serial: UInt32) {
        unsafe swl_xdg_toplevel_move(pointer, seat.pointer, serial)
    }

    package func resize(seat: RawSeat, serial: UInt32, edge: RawXDGTopLevelResizeEdge) {
        unsafe swl_xdg_toplevel_resize(pointer, seat.pointer, serial, edge.rawValue)
    }

    package func setMaximumSize(width: Int32, height: Int32) {
        unsafe swl_xdg_toplevel_set_max_size(pointer, width, height)
    }

    package func setMinimumSize(width: Int32, height: Int32) {
        unsafe swl_xdg_toplevel_set_min_size(pointer, width, height)
    }

    package func setParent(_ parent: RawXDGTopLevel?) {
        unsafe swl_xdg_toplevel_set_parent(pointer, parent?.pointer)
    }

    package func setMaximized() {
        unsafe swl_xdg_toplevel_set_maximized(pointer)
    }

    package func unsetMaximized() {
        unsafe swl_xdg_toplevel_unset_maximized(pointer)
    }

    package func setFullscreen(output: RawOutput? = nil) {
        unsafe swl_xdg_toplevel_set_fullscreen(pointer, output?.pointer)
    }

    package func unsetFullscreen() {
        unsafe swl_xdg_toplevel_unset_fullscreen(pointer)
    }

    package func setMinimized() {
        unsafe swl_xdg_toplevel_set_minimized(pointer)
    }
}
