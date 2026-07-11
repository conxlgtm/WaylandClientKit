public enum CursorConfigurationError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyThemeName
    case themeNameContainsInteriorNUL
    case invalidSize(Int32)
    case cursorNameContainsInteriorNUL
    case emptyCursorName
    case invalidCursorImagePixelCount(expected: Int, actual: Int)
    case cursorImageHotspotOutsideBounds(x: Int32, y: Int32, width: Int32, height: Int32)
    case emptyCursorAnimation
    case nonPositiveCursorFrameDuration(Duration)

    public var description: String {
        switch self {
        case .emptyThemeName:
            "cursor theme name must not be empty"
        case .themeNameContainsInteriorNUL:
            "cursor theme name must not contain embedded NUL bytes"
        case .invalidSize(let value):
            "cursor size must be greater than zero, got \(value)"
        case .cursorNameContainsInteriorNUL:
            "pointer cursor names must not contain embedded NUL bytes"
        case .emptyCursorName:
            "pointer cursor names must not be empty"
        case .invalidCursorImagePixelCount(let expected, let actual):
            "pointer cursor image expected \(expected) pixels, got \(actual)"
        case .cursorImageHotspotOutsideBounds(let x, let y, let width, let height):
            "pointer cursor hotspot \(x),\(y) must be inside \(width)x\(height)"
        case .emptyCursorAnimation:
            "animated pointer cursors must contain at least one frame"
        case .nonPositiveCursorFrameDuration(let duration):
            "animated pointer cursor frame duration must be positive, got \(duration)"
        }
    }
}

public struct CursorThemeName: Equatable, Sendable, CustomStringConvertible {
    public let value: String

    public init(_ name: String) throws {
        guard !name.isEmpty else {
            throw CursorConfigurationError.emptyThemeName
        }

        guard !name.contains("\0") else {
            throw CursorConfigurationError.themeNameContainsInteriorNUL
        }

        value = name
    }

    public var description: String {
        value
    }
}

public struct CursorSize: Equatable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int32

    public static let `default` = CursorSize(unchecked: 24)

    public init(_ value: Int32) throws {
        guard value > 0 else {
            throw CursorConfigurationError.invalidSize(value)
        }

        rawValue = value
    }

    package init(unchecked value: Int32) {
        precondition(value > 0, "cursor size must be positive")
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
