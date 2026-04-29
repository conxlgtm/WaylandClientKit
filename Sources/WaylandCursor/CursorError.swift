public enum CursorError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidSize(Int32)
    case themeLoadFailed
    case missingCursor(String)
    case missingImage(String)
    case missingBuffer(String)
    case invalidImageDimension(UInt32)

    public var description: String {
        switch self {
        case .invalidSize(let size):
            "Cursor size must be greater than zero, got \(size)"
        case .themeLoadFailed:
            "Cursor theme load failed"
        case .missingCursor(let name):
            "Cursor theme does not contain cursor: \(name)"
        case .missingImage(let name):
            "Cursor has no images: \(name)"
        case .missingBuffer(let name):
            "Cursor image has no Wayland buffer: \(name)"
        case .invalidImageDimension(let value):
            "Cursor image dimension does not fit Int32: \(value)"
        }
    }
}
