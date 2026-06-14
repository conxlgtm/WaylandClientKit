public struct PointerCursorImage: Equatable, Sendable {
    public let size: PositivePixelSize
    public let hotspotX: Int32
    public let hotspotY: Int32
    public let pixels: [UInt32]

    public init(
        size imageSize: PositivePixelSize,
        hotspotX imageHotspotX: Int32,
        hotspotY imageHotspotY: Int32,
        pixels xrgb8888Pixels: [UInt32]
    ) throws {
        try Self.validateHotspot(
            x: imageHotspotX,
            y: imageHotspotY,
            width: imageSize.width.rawValue,
            height: imageSize.height.rawValue
        )
        try Self.validatePixelCount(
            width: Int(imageSize.width.rawValue),
            height: Int(imageSize.height.rawValue),
            actual: xrgb8888Pixels.count
        )

        size = imageSize
        hotspotX = imageHotspotX
        hotspotY = imageHotspotY
        pixels = xrgb8888Pixels
    }

    // swiftlint:disable function_default_parameter_at_end
    public static func solid(
        size imageSize: PositivePixelSize,
        hotspotX imageHotspotX: Int32 = 0,
        hotspotY imageHotspotY: Int32 = 0,
        color xrgb8888Color: UInt32
    ) throws -> PointerCursorImage {
        let expectedCount = try expectedPixelCount(
            width: Int(imageSize.width.rawValue),
            height: Int(imageSize.height.rawValue),
            actualForError: 0
        )
        return try PointerCursorImage(
            size: imageSize,
            hotspotX: imageHotspotX,
            hotspotY: imageHotspotY,
            pixels: Array(repeating: xrgb8888Color, count: expectedCount)
        )
    }
    // swiftlint:enable function_default_parameter_at_end

    @discardableResult
    package static func validatePixelCount(
        width: Int,
        height: Int,
        actual: Int
    ) throws -> Int {
        let expectedCount = try expectedPixelCount(
            width: width,
            height: height,
            actualForError: actual
        )

        guard actual == expectedCount else {
            throw ClientError.cursor(
                .invalidConfiguration(
                    .invalidCursorImagePixelCount(expected: expectedCount, actual: actual)
                ))
        }

        return expectedCount
    }

    private static func expectedPixelCount(
        width: Int,
        height: Int,
        actualForError actual: Int
    ) throws -> Int {
        let (expectedCount, overflowed) = width.multipliedReportingOverflow(by: height)
        guard !overflowed else {
            throw ClientError.cursor(
                .invalidConfiguration(
                    .invalidCursorImagePixelCount(expected: Int.max, actual: actual)
                ))
        }

        return expectedCount
    }

    private static func validateHotspot(
        x: Int32,
        y: Int32,
        width: Int32,
        height: Int32
    ) throws {
        guard x >= 0, y >= 0, x < width, y < height else {
            throw ClientError.cursor(
                .invalidConfiguration(
                    .cursorImageHotspotOutsideBounds(
                        x: x,
                        y: y,
                        width: width,
                        height: height
                    )
                ))
        }
    }
}

/// One frame in an animated pointer cursor.
///
/// The frame image uses the same XRGB8888 pixel format as
/// ``PointerCursorImage`` for static custom cursor images.
public struct PointerCursorFrame: Equatable, Sendable {
    public let image: PointerCursorImage
    public let duration: Duration

    public init(image frameImage: PointerCursorImage, duration frameDuration: Duration) throws {
        guard frameDuration > .zero else {
            throw ClientError.cursor(
                .invalidConfiguration(.nonPositiveCursorFrameDuration(frameDuration))
            )
        }

        image = frameImage
        duration = frameDuration
    }
}

/// A validated custom animated pointer cursor.
///
/// WaylandClientKit treats each frame as a normal custom cursor image. The
/// public value does not expose cursor surfaces, buffers, timers, queues, or SHM
/// pools.
public struct AnimatedPointerCursor: Equatable, Sendable {
    public let frames: [PointerCursorFrame]

    public init(frames animationFrames: [PointerCursorFrame]) throws {
        guard !animationFrames.isEmpty else {
            throw ClientError.cursor(.invalidConfiguration(.emptyCursorAnimation))
        }

        frames = animationFrames
    }
}

public struct PointerCursor: Equatable, Sendable {
    package enum Kind: Equatable, Sendable {
        case named(String)
        case customImage(PointerCursorImage)
        case animated(AnimatedPointerCursor)
        case hidden
    }

    package let kind: Kind

    public var name: String? {
        guard case .named(let name) = kind else { return nil }
        return name
    }

    public var image: PointerCursorImage? {
        guard case .customImage(let image) = kind else { return nil }
        return image
    }

    public var animation: AnimatedPointerCursor? {
        guard case .animated(let animation) = kind else { return nil }
        return animation
    }

    public init(name cursorName: String) throws {
        guard !cursorName.isEmpty else {
            throw ClientError.cursor(.invalidConfiguration(.emptyCursorName))
        }

        guard !cursorName.contains("\0") else {
            throw ClientError.cursor(.invalidConfiguration(.cursorNameContainsInteriorNUL))
        }

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

    public static func image(_ image: PointerCursorImage) -> PointerCursor {
        Self(kind: .customImage(image))
    }

    public static func animated(_ cursor: AnimatedPointerCursor) throws -> PointerCursor {
        guard !cursor.frames.isEmpty else {
            throw ClientError.cursor(.invalidConfiguration(.emptyCursorAnimation))
        }

        return Self(kind: .animated(cursor))
    }

    public static let defaultArrow = Self(validatedName: "left_ptr")
    public static let text = Self(validatedName: "text")
    public static let pointer = Self(validatedName: "hand2")
    public static let crosshair = Self(validatedName: "crosshair")
    public static let resizeLeftRight = Self(validatedName: "sb_h_double_arrow")
    public static let resizeUpDown = Self(validatedName: "sb_v_double_arrow")
    public static let hidden = Self(kind: .hidden)
}
