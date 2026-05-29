public enum CursorConfigurationError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyThemeName
    case themeNameContainsInteriorNUL
    case invalidSize(Int32)
    case cursorNameContainsInteriorNUL
    case emptyCursorName
    case invalidCursorImagePixelCount(expected: Int, actual: Int)
    case cursorImageHotspotOutsideBounds(x: Int32, y: Int32, width: Int32, height: Int32)

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
        precondition(!name.isEmpty, "cursor theme name must not be empty")
        precondition(!name.contains("\0"), "cursor theme name must not contain NUL bytes")
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

public enum DisplayConfigurationField: Equatable, Sendable, CustomStringConvertible {
    case displayEventCapacity
    case inputEventCapacity
    case textInputEventCapacity
    case dataTransferEventCapacity
    case presentationEventCapacity
    case rawInputQueueCapacity
    case pendingInputEventCapacity
    case diagnosticsCapacity

    public var description: String {
        switch self {
        case .displayEventCapacity:
            "displayEventCapacity"
        case .inputEventCapacity:
            "inputEventCapacity"
        case .textInputEventCapacity:
            "textInputEventCapacity"
        case .dataTransferEventCapacity:
            "dataTransferEventCapacity"
        case .presentationEventCapacity:
            "presentationEventCapacity"
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

public enum EventStreamCapacityField: Equatable, Sendable {
    case displayEventCapacity
    case inputEventCapacity
    case textInputEventCapacity
    case dataTransferEventCapacity
    case presentationEventCapacity

    var displayConfigurationField: DisplayConfigurationField {
        switch self {
        case .displayEventCapacity:
            .displayEventCapacity
        case .inputEventCapacity:
            .inputEventCapacity
        case .textInputEventCapacity:
            .textInputEventCapacity
        case .dataTransferEventCapacity:
            .dataTransferEventCapacity
        case .presentationEventCapacity:
            .presentationEventCapacity
        }
    }
}

public struct EventStreamCapacity: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public static let defaultDisplayEvents = EventStreamCapacity(unchecked: 256)
    public static let defaultInputEvents = EventStreamCapacity(unchecked: 1_024)
    public static let defaultTextInputEvents = EventStreamCapacity(unchecked: 512)
    public static let defaultDataTransferEvents = EventStreamCapacity(unchecked: 256)
    public static let defaultPresentationEvents = EventStreamCapacity(unchecked: 256)

    public init(
        _ value: Int,
        field: EventStreamCapacityField
    ) throws {
        guard value > 0 else {
            throw DisplayConfigurationError.nonPositiveCapacity(
                field: field.displayConfigurationField,
                value: value
            )
        }

        rawValue = value
    }

    package init(unchecked value: Int) {
        precondition(value > 0, "event stream capacity must be positive")
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum InputQueueCapacityField: Equatable, Sendable {
    case rawInputQueueCapacity
    case pendingInputEventCapacity

    var displayConfigurationField: DisplayConfigurationField {
        switch self {
        case .rawInputQueueCapacity:
            .rawInputQueueCapacity
        case .pendingInputEventCapacity:
            .pendingInputEventCapacity
        }
    }
}

public struct InputQueueCapacity: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public static let defaultRawInput = InputQueueCapacity(unchecked: 4_096)
    public static let defaultPendingInput = InputQueueCapacity(unchecked: 2_048)

    public init(
        _ value: Int,
        field: InputQueueCapacityField
    ) throws {
        guard value > 0 else {
            throw DisplayConfigurationError.nonPositiveCapacity(
                field: field.displayConfigurationField,
                value: value
            )
        }

        rawValue = value
    }

    package init(unchecked value: Int) {
        precondition(value > 0, "input queue capacity must be positive")
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
        precondition(value > 0, "diagnostics capacity must be positive")
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
