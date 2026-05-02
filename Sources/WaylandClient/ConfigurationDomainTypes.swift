public enum CursorConfigurationError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyThemeName
    case themeNameContainsInteriorNUL
    case invalidSize(Int32)
    case cursorNameContainsInteriorNUL
    case emptyCursorName

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

    package init(unchecked name: String) {
        value = name
    }

    public var description: String {
        value
    }
}

public struct CursorSize: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int32

    public static let `default` = CursorSize(unchecked: 24)

    public init(_ value: Int32) throws {
        guard value > 0 else {
            throw CursorConfigurationError.invalidSize(value)
        }

        rawValue = value
    }

    package init(unchecked value: Int32) {
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum DisplayConfigurationField: Equatable, Sendable, CustomStringConvertible {
    case displayEventCapacity
    case inputEventCapacity
    case rawInputQueueCapacity
    case pendingInputEventCapacity
    case diagnosticsCapacity

    public var description: String {
        switch self {
        case .displayEventCapacity:
            "displayEventCapacity"
        case .inputEventCapacity:
            "inputEventCapacity"
        case .rawInputQueueCapacity:
            "rawInputQueueCapacity"
        case .pendingInputEventCapacity:
            "pendingInputEventCapacity"
        case .diagnosticsCapacity:
            "diagnostics capacity"
        }
    }
}

public enum DisplayConfigurationError: Error, Equatable, Sendable, CustomStringConvertible {
    case nonPositiveCapacity(field: DisplayConfigurationField, value: Int)

    public var description: String {
        switch self {
        case .nonPositiveCapacity(let field, let value):
            "\(field.description) must be greater than zero, got \(value)"
        }
    }
}

public struct EventStreamCapacity: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public static let defaultDisplayEvents = EventStreamCapacity(unchecked: 256)
    public static let defaultInputEvents = EventStreamCapacity(unchecked: 1_024)

    public init(
        _ value: Int,
        field: DisplayConfigurationField
    ) throws {
        guard value > 0 else {
            throw DisplayConfigurationError.nonPositiveCapacity(field: field, value: value)
        }

        rawValue = value
    }

    package init(unchecked value: Int) {
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct InputQueueCapacity: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public static let defaultRawInput = InputQueueCapacity(unchecked: 4_096)
    public static let defaultPendingInput = InputQueueCapacity(unchecked: 2_048)

    public init(
        _ value: Int,
        field: DisplayConfigurationField
    ) throws {
        guard value > 0 else {
            throw DisplayConfigurationError.nonPositiveCapacity(field: field, value: value)
        }

        rawValue = value
    }

    package init(unchecked value: Int) {
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct DiagnosticsCapacity: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public static let `default` = DiagnosticsCapacity(unchecked: 128)

    public init(_ value: Int) throws {
        guard value > 0 else {
            throw DisplayConfigurationError.nonPositiveCapacity(
                field: .diagnosticsCapacity,
                value: value
            )
        }

        rawValue = value
    }

    package init(unchecked value: Int) {
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
