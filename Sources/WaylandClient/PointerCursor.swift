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

    public init(name cursorName: String) throws {
        try CStringValidation.requireNonEmptyNoInteriorNUL(
            cursorName,
            fieldName: "Pointer cursor names",
            error: ClientError.invalidCursorConfiguration
        )

        kind = .named(cursorName)
    }

    package init(validatedName cursorName: String) {
        precondition(!cursorName.isEmpty, "Pointer cursor names must not be empty")
        precondition(!cursorName.contains("\0"), "Pointer cursor names must not contain NUL bytes")
        kind = .named(cursorName)
    }

    package init(kind cursorKind: Kind) {
        kind = cursorKind
    }

    public static let defaultArrow = Self(validatedName: "left_ptr")
    public static let text = Self(validatedName: "text")
    public static let pointer = Self(validatedName: "hand2")
    public static let crosshair = Self(validatedName: "crosshair")
    public static let resizeLeftRight = Self(validatedName: "sb_h_double_arrow")
    public static let resizeUpDown = Self(validatedName: "sb_v_double_arrow")
    public static let hidden = Self(kind: .hidden)
}
