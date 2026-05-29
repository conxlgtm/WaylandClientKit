import WaylandRaw

extension PointerCursor {
    package var cursorShapeName: RawCursorShapeName? {
        switch kind {
        case .hidden, .customImage:
            nil
        case .named(let name):
            switch name {
            case "left_ptr":
                .default
            case "text":
                .text
            case "hand2":
                .pointer
            case "crosshair":
                .crosshair
            case "sb_h_double_arrow":
                .ewResize
            case "sb_v_double_arrow":
                .nsResize
            default:
                nil
            }
        }
    }
}
