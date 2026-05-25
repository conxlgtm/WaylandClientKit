public enum PointerCursorScalePolicy: Equatable, Sendable {
    case fixed
    case matchFocusedOutput
    case maximumOutputScale
}

public struct CursorConfiguration: Equatable, Sendable {
    public var themeName: CursorThemeName?
    public var size: CursorSize
    public var scalePolicy: PointerCursorScalePolicy
    public var fallbackCursor: PointerCursor

    public init(
        themeName cursorThemeName: CursorThemeName? = nil,
        size cursorSize: CursorSize = .default,
        scalePolicy cursorScalePolicy: PointerCursorScalePolicy = .fixed,
        fallbackCursor cursorFallback: PointerCursor = .defaultArrow
    ) {
        themeName = cursorThemeName
        size = cursorSize
        scalePolicy = cursorScalePolicy
        fallbackCursor = cursorFallback
    }

    public init(
        themeName cursorThemeName: String?,
        size cursorSize: Int32 = CursorSize.default.rawValue,
        scalePolicy cursorScalePolicy: PointerCursorScalePolicy = .fixed,
        fallbackCursor cursorFallback: PointerCursor = .defaultArrow
    ) throws {
        if let cursorThemeName {
            themeName = try CursorThemeName(cursorThemeName)
        } else {
            themeName = nil
        }
        size = try CursorSize(cursorSize)
        scalePolicy = cursorScalePolicy
        fallbackCursor = cursorFallback
    }
}

extension PointerCursorScalePolicy {
    package var internalPolicy: CursorScalePolicy {
        switch self {
        case .fixed:
            .fixed
        case .matchFocusedOutput:
            .matchFocusedSurface
        case .maximumOutputScale:
            .maximumOutputScale
        }
    }
}
