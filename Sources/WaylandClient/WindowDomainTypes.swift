import WaylandRaw

public struct WaylandString: Equatable, Sendable, CustomStringConvertible {
    public let value: String

    public init(_ string: String) throws {
        guard !string.contains("\0") else {
            throw ClientError.invalidWindowConfiguration(.interiorNUL(field: "WaylandString"))
        }

        value = string
    }

    package init(unchecked string: String) {
        value = string
    }

    public var description: String {
        value
    }
}

public struct NonEmptyWaylandString: Equatable, Sendable, CustomStringConvertible {
    public let value: String

    public init(_ string: String) throws {
        guard !string.isEmpty else {
            throw ClientError.invalidWindowConfiguration(
                .emptyString(field: "NonEmptyWaylandString")
            )
        }

        guard !string.contains("\0") else {
            throw ClientError.invalidWindowConfiguration(
                .interiorNUL(field: "NonEmptyWaylandString")
            )
        }

        value = string
    }

    package init(unchecked string: String) {
        value = string
    }

    public var description: String {
        value
    }
}

public struct PositiveInt32: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int32

    public init(_ value: Int32) throws {
        guard value > 0 else {
            throw ClientError.invalidWindowConfiguration(.nonPositiveInt32(value: value))
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

public struct PositiveInt: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(_ value: Int) throws {
        guard value > 0 else {
            throw ClientError.invalidWindowConfiguration(.nonPositiveInt(value: value))
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

public struct PositiveTopLevelSize: Equatable, Sendable, CustomStringConvertible {
    public let width: PositiveInt32
    public let height: PositiveInt32

    public static let `default` = PositiveTopLevelSize(
        width: PositiveInt32(unchecked: 640),
        height: PositiveInt32(unchecked: 480)
    )

    public init(width sizeWidth: PositiveInt32, height sizeHeight: PositiveInt32) {
        width = sizeWidth
        height = sizeHeight
    }

    public init(width sizeWidth: Int32, height sizeHeight: Int32) throws {
        width = try PositiveInt32(sizeWidth)
        height = try PositiveInt32(sizeHeight)
    }

    var rawSize: TopLevelSize {
        TopLevelSize(width: width.rawValue, height: height.rawValue)
    }

    public var description: String {
        "\(width.rawValue)x\(height.rawValue)"
    }
}

public struct Milliseconds: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: Int32

    public init(_ value: Int32) throws {
        guard value >= 0 else {
            throw ClientError.invalidWindowConfiguration(.negativeMilliseconds(value: value))
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

package enum ProtocolDimensionSuggestion: Equatable, Sendable {
    case unspecified
    case suggested(PositiveInt32)

    var suggestedValue: PositiveInt32? {
        switch self {
        case .unspecified:
            nil
        case .suggested(let value):
            value
        }
    }
}

package struct TopLevelSizeSuggestion: Equatable, Sendable {
    let width: ProtocolDimensionSuggestion
    let height: ProtocolDimensionSuggestion

    init(
        width sizeWidth: ProtocolDimensionSuggestion,
        height sizeHeight: ProtocolDimensionSuggestion
    ) {
        width = sizeWidth
        height = sizeHeight
    }

    static func normalize(width: Int32, height: Int32) throws -> Self {
        guard width >= 0, height >= 0 else {
            throw WindowError.invalidConfigure(
                .negativeSuggestedDimension(width: width, height: height)
            )
        }

        return Self(
            width: try normalizeDimension(width),
            height: try normalizeDimension(height)
        )
    }

    func resolve(
        previous: PositiveTopLevelSize?,
        fallback: PositiveTopLevelSize
    ) throws -> PositiveTopLevelSize {
        PositiveTopLevelSize(
            width: width.suggestedValue ?? previous?.width ?? fallback.width,
            height: height.suggestedValue ?? previous?.height ?? fallback.height
        )
    }

    private static func normalizeDimension(
        _ value: Int32
    ) throws -> ProtocolDimensionSuggestion {
        guard value > 0 else {
            return .unspecified
        }

        return .suggested(PositiveInt32(unchecked: value))
    }
}

package struct ResolvedWindowConfiguration: Equatable, Sendable {
    let serial: UInt32
    let size: PositiveTopLevelSize
    let states: [XDGTopLevelState]
    let bounds: PositiveTopLevelSize?
    let wmCapabilities: [XDGWMCapability]

    init(
        sequence: XDGConfigureSequence,
        previousSize: PositiveTopLevelSize?,
        fallbackSize: PositiveTopLevelSize
    ) throws {
        let suggestion = try TopLevelSizeSuggestion.normalize(
            width: sequence.topLevel.size.width,
            height: sequence.topLevel.size.height
        )
        let resolvedBounds: PositiveTopLevelSize?
        if let bounds = sequence.topLevel.bounds {
            guard bounds.width > 0, bounds.height > 0 else {
                throw WindowError.invalidConfigure(
                    .negativeSuggestedDimension(width: bounds.width, height: bounds.height)
                )
            }
            resolvedBounds = PositiveTopLevelSize(
                width: PositiveInt32(unchecked: bounds.width),
                height: PositiveInt32(unchecked: bounds.height)
            )
        } else {
            resolvedBounds = nil
        }

        serial = sequence.serial
        size = try suggestion.resolve(previous: previousSize, fallback: fallbackSize)
        states = sequence.topLevel.states
        bounds = resolvedBounds
        wmCapabilities = sequence.topLevel.wmCapabilities
    }
}
