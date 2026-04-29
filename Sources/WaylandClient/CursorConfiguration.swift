public struct CursorConfiguration: Equatable, Sendable {
    public var themeName: String?
    public var size: Int32
    public var fallbackCursor: PointerCursor

    public init(
        themeName cursorThemeName: String? = nil,
        size cursorSize: Int32 = 24,
        fallbackCursor cursorFallback: PointerCursor = .defaultArrow
    ) {
        themeName = cursorThemeName
        size = cursorSize
        fallbackCursor = cursorFallback
    }
}
