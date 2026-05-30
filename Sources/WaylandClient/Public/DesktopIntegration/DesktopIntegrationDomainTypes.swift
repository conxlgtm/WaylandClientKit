public struct WindowIconName: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let value: String

    public init(_ iconName: String) throws {
        guard !iconName.isEmpty else {
            throw ClientError.display(.emptyWindowIconName)
        }
        guard !iconName.contains("\0") else {
            throw ClientError.display(.windowIconNameContainsNUL)
        }

        value = iconName
    }

    public var description: String {
        value
    }
}

public struct WindowIconImage: Equatable, Sendable {
    public let size: PositivePixelSize
    public let scale: PositiveInt32
    public let pixels: [UInt32]

    public init(
        size imageSize: PositivePixelSize,
        pixels xrgb8888Pixels: [UInt32]
    ) throws {
        try self.init(
            size: imageSize,
            scale: try PositiveInt32(1),
            pixels: xrgb8888Pixels
        )
    }

    public init(
        size imageSize: PositivePixelSize,
        scale imageScale: PositiveInt32,
        pixels xrgb8888Pixels: [UInt32]
    ) throws {
        guard imageSize.width == imageSize.height else {
            throw ClientError.display(
                .nonSquareWindowIconImage(
                    width: imageSize.width.rawValue,
                    height: imageSize.height.rawValue
                )
            )
        }

        let expected = try Self.expectedPixelCount(
            width: Int(imageSize.width.rawValue),
            height: Int(imageSize.height.rawValue),
            actualForError: xrgb8888Pixels.count
        )
        guard xrgb8888Pixels.count == expected else {
            throw ClientError.display(
                .invalidWindowIconImagePixelCount(
                    expected: expected,
                    actual: xrgb8888Pixels.count
                )
            )
        }

        size = imageSize
        scale = imageScale
        pixels = xrgb8888Pixels
    }

    public static func solid(
        size imageSize: PositivePixelSize,
        color xrgb8888Color: UInt32
    ) throws -> WindowIconImage {
        try solid(
            size: imageSize,
            scale: try PositiveInt32(1),
            color: xrgb8888Color
        )
    }

    public static func solid(
        size imageSize: PositivePixelSize,
        scale imageScale: PositiveInt32,
        color xrgb8888Color: UInt32
    ) throws -> WindowIconImage {
        let expected = try expectedPixelCount(
            width: Int(imageSize.width.rawValue),
            height: Int(imageSize.height.rawValue),
            actualForError: 0
        )
        return try WindowIconImage(
            size: imageSize,
            scale: imageScale,
            pixels: Array(repeating: xrgb8888Color, count: expected)
        )
    }

    private static func expectedPixelCount(
        width: Int,
        height: Int,
        actualForError actual: Int
    ) throws -> Int {
        let (expected, overflowed) = width.multipliedReportingOverflow(by: height)
        guard !overflowed else {
            throw ClientError.display(
                .invalidWindowIconImagePixelCount(expected: Int.max, actual: actual)
            )
        }

        return expected
    }
}

public enum WindowIcon: Equatable, Sendable {
    case none
    case named(WindowIconName)
    case xrgb8888(WindowIconImage)
}

public struct IdleInhibitorID:
    Hashable,
    Sendable,
    CustomStringConvertible,
    UInt64WaylandEntityID,
    PrefixedIdentityDescription
{
    package static let descriptionPrefix = "idle-inhibitor"
    package let rawValue: UInt64

    package init(rawValue inhibitorRawValue: UInt64) {
        rawValue = inhibitorRawValue
    }

    public var description: String {
        "\(Self.descriptionPrefix)-\(rawValue)"
    }
}

public struct IdleInhibitor: Sendable, Hashable, Identifiable {
    public let id: IdleInhibitorID

    private let display: WaylandDisplay
    private let ownership: DisplayOwnedIdentity<IdleInhibitorID>

    package init(id inhibitorID: IdleInhibitorID, display owningDisplay: WaylandDisplay) {
        id = inhibitorID
        display = owningDisplay
        ownership = DisplayOwnedIdentity(id: inhibitorID, display: owningDisplay)
    }

    package func isOwned(by owningDisplay: WaylandDisplay) -> Bool {
        ownership.isOwned(by: owningDisplay)
    }

    public func destroy() async throws {
        guard isOwned(by: display) else {
            throw ClientError.display(.foreignIdleInhibitor(id))
        }

        try await display.destroyIdleInhibitor(id)
    }

    public static func == (lhs: IdleInhibitor, rhs: IdleInhibitor) -> Bool {
        lhs.ownership == rhs.ownership
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ownership)
    }
}
