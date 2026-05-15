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
        precondition(!string.contains("\0"), "Wayland string must not contain NUL bytes")
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
        precondition(!string.isEmpty, "Wayland string must not be empty")
        precondition(!string.contains("\0"), "Wayland string must not contain NUL bytes")
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
        precondition(value > 0, "positive Int32 value must be positive")
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
        precondition(value > 0, "positive Int value must be positive")
        rawValue = value
    }

    public var description: String {
        String(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct PositiveLogicalSize: Equatable, Sendable, CustomStringConvertible {
    public let width: PositiveInt32
    public let height: PositiveInt32

    public static let `default` = PositiveLogicalSize(
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

public struct PositivePixelSize: Equatable, Sendable, CustomStringConvertible {
    public let width: PositiveInt32
    public let height: PositiveInt32

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

public struct SurfaceScale: Equatable, Sendable, CustomStringConvertible {
    public let numerator: UInt32
    public let denominator: UInt32

    public static let one = SurfaceScale(uncheckedNumerator: 1, denominator: 1)
    package static let fractionalScaleDenominator: UInt32 = 120

    public init(numerator scaleNumerator: UInt32, denominator scaleDenominator: UInt32)
        throws
    {
        guard scaleNumerator > 0 else {
            throw ClientError.invalidWindowConfiguration(
                .nonPositiveScaleNumerator(scaleNumerator)
            )
        }

        guard scaleNumerator <= UInt32(Int32.max) else {
            throw ClientError.invalidWindowConfiguration(
                .scaleNumeratorTooLarge(scaleNumerator)
            )
        }

        guard scaleDenominator > 0 else {
            throw ClientError.invalidWindowConfiguration(.zeroScaleDenominator)
        }

        numerator = scaleNumerator
        denominator = scaleDenominator
    }

    package init(uncheckedNumerator scaleNumerator: UInt32, denominator scaleDenominator: UInt32) {
        precondition(scaleNumerator > 0, "scale numerator must be positive")
        precondition(scaleNumerator <= UInt32(Int32.max), "scale numerator must fit in Int32")
        precondition(scaleDenominator > 0, "scale denominator must be positive")
        numerator = scaleNumerator
        denominator = scaleDenominator
    }

    package init(integerScale scale: Int32) throws {
        guard scale > 0 else {
            throw WindowError.invalidConfigure(.invalidPreferredBufferScale(scale))
        }

        numerator = UInt32(scale)
        denominator = 1
    }

    package init(fractionalScaleNumerator scaleNumerator: UInt32) throws {
        guard scaleNumerator > 0 else {
            throw ClientError.invalidWindowConfiguration(
                .nonPositiveScaleNumerator(scaleNumerator)
            )
        }

        guard scaleNumerator <= UInt32(Int32.max) else {
            throw ClientError.invalidWindowConfiguration(
                .scaleNumeratorTooLarge(scaleNumerator)
            )
        }

        numerator = scaleNumerator
        denominator = SurfaceScale.fractionalScaleDenominator
    }

    public var description: String {
        if denominator == 1 {
            return "\(numerator)"
        }

        return "\(numerator)/\(denominator)"
    }

    package var isInteger: Bool {
        denominator == 1
    }

    package var integerValue: Int32? {
        guard denominator == 1, numerator <= UInt32(Int32.max) else {
            return nil
        }

        return Int32(numerator)
    }

    package func bufferSize(for logicalSize: PositiveLogicalSize) throws -> PositivePixelSize {
        try PositivePixelSize(
            width: scaledDimension(logicalSize.width.rawValue),
            height: scaledDimension(logicalSize.height.rawValue)
        )
    }

    private func scaledDimension(_ value: Int32) throws -> PositiveInt32 {
        let scaled = Int64(value) * Int64(numerator)
        let divisor = Int64(denominator)
        let quotient = scaled / divisor
        let remainder = scaled % divisor
        let rounded = max(1, quotient + (remainder * 2 >= divisor ? 1 : 0))

        guard rounded <= Int64(Int32.max) else {
            throw WindowError.invalidConfigure(
                .unrepresentableSurfaceBufferSize(
                    logicalDimension: value,
                    scaleNumerator: numerator,
                    scaleDenominator: denominator
                )
            )
        }

        return PositiveInt32(unchecked: Int32(rounded))
    }
}

public struct SurfaceGeometry: Equatable, Sendable, CustomStringConvertible {
    public let logicalSize: PositiveLogicalSize
    public let bufferSize: PositivePixelSize
    public let scale: SurfaceScale

    public init(
        logicalSize surfaceLogicalSize: PositiveLogicalSize,
        scale surfaceScale: SurfaceScale
    ) throws {
        logicalSize = surfaceLogicalSize
        scale = surfaceScale
        bufferSize = try surfaceScale.bufferSize(for: surfaceLogicalSize)
    }

    public var description: String {
        "logical \(logicalSize), buffer \(bufferSize), scale \(scale)"
    }
}

public struct SoftwareFrameGeometry: Equatable, Sendable {
    public let surface: SurfaceGeometry

    public var logicalSize: PositiveLogicalSize {
        surface.logicalSize
    }

    public var bufferSize: PositivePixelSize {
        surface.bufferSize
    }

    public var scale: SurfaceScale {
        surface.scale
    }

    public init(surface surfaceGeometry: SurfaceGeometry) {
        surface = surfaceGeometry
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
        precondition(value >= 0, "milliseconds value must be non-negative")
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
        previous: PositiveLogicalSize?,
        fallback: PositiveLogicalSize
    ) throws -> PositiveLogicalSize {
        PositiveLogicalSize(
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
    let size: PositiveLogicalSize
    let states: [WindowStateToken]
    let bounds: PositiveLogicalSize?
    let wmCapabilities: [WindowManagerCapability]
    let decorationMode: WindowDecorationMode?

    init(
        sequence: XDGConfigureSequence,
        previousSize: PositiveLogicalSize?,
        fallbackSize: PositiveLogicalSize
    ) throws {
        let suggestion = try TopLevelSizeSuggestion.normalize(
            width: sequence.topLevel.size.width,
            height: sequence.topLevel.size.height
        )
        let resolvedBounds: PositiveLogicalSize?
        if let bounds = sequence.topLevel.bounds {
            guard bounds.width > 0, bounds.height > 0 else {
                throw WindowError.invalidConfigure(
                    .negativeSuggestedDimension(width: bounds.width, height: bounds.height)
                )
            }
            resolvedBounds = PositiveLogicalSize(
                width: PositiveInt32(unchecked: bounds.width),
                height: PositiveInt32(unchecked: bounds.height)
            )
        } else {
            resolvedBounds = nil
        }

        serial = sequence.serial
        size = try suggestion.resolve(previous: previousSize, fallback: fallbackSize)
        states = sequence.topLevel.states.map(WindowStateToken.init)
        bounds = resolvedBounds
        wmCapabilities = sequence.topLevel.wmCapabilities.map(WindowManagerCapability.init)
        decorationMode = sequence.decorationMode.map(WindowDecorationMode.init)
    }
}

extension WindowDecorationMode {
    package init(_ rawMode: RawDecorationMode) {
        switch rawMode {
        case .clientSide:
            self = .clientSide
        case .serverSide:
            self = .serverSide
        case .unknown(let rawValue):
            self = .unknown(rawValue)
        }
    }
}

package enum DecorationModeRequest: Equatable, Sendable {
    case set(RawDecorationMode)
    case unset

    package init(preference: WindowDecorationPreference) {
        switch preference {
        case .preferServerSide:
            self = .set(.serverSide)
        case .preferClientSide:
            self = .set(.clientSide)
        case .compositorDefault:
            self = .unset
        }
    }

    package func apply(to decoration: RawXDGToplevelDecoration) {
        switch self {
        case .set(let mode):
            decoration.setMode(mode)
        case .unset:
            decoration.unsetMode()
        }
    }
}

extension WindowDecorationPreference {
    package var shouldReportMissingDecorationManager: Bool {
        self == .preferServerSide
    }
}
