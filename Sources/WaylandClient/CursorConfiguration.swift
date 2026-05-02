public struct CursorConfiguration: Equatable, Sendable {
    public var themeName: CursorThemeName?
    public var size: CursorSize
    public var fallbackCursor: PointerCursor

    public init(
        themeName cursorThemeName: CursorThemeName? = nil,
        size cursorSize: CursorSize = .default,
        fallbackCursor cursorFallback: PointerCursor = .defaultArrow
    ) {
        themeName = cursorThemeName
        size = cursorSize
        fallbackCursor = cursorFallback
    }

    public init(
        themeName cursorThemeName: String?,
        size cursorSize: Int32 = CursorSize.default.rawValue,
        fallbackCursor cursorFallback: PointerCursor = .defaultArrow
    ) throws {
        if let cursorThemeName {
            themeName = try CursorThemeName(cursorThemeName)
        } else {
            themeName = nil
        }
        size = try CursorSize(cursorSize)
        fallbackCursor = cursorFallback
    }
}
