public struct PointerCursor: Equatable, Sendable {
    package enum Kind: Equatable, Sendable {
        case named(String)
        case hidden
    }

    package let kind: Kind

    public var name: String? {
        guard case .named(let name) = kind else { return nil }
        return name
    }

    public init(name cursorName: String) {
        precondition(!cursorName.isEmpty, "Pointer cursor names must not be empty")
        kind = .named(cursorName)
    }

    package init(kind cursorKind: Kind) {
        kind = cursorKind
    }

    public static let defaultArrow = Self(name: "left_ptr")
    public static let text = Self(name: "text")
    public static let pointer = Self(name: "hand2")
    public static let crosshair = Self(name: "crosshair")
    public static let resizeLeftRight = Self(name: "sb_h_double_arrow")
    public static let resizeUpDown = Self(name: "sb_v_double_arrow")
    public static let hidden = Self(kind: .hidden)
}
