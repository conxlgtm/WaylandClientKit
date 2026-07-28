/// Renderer-neutral metadata applied to one surface frame commit.
///
/// `damage == nil` is the only full-frame damage representation. A non-`nil`
/// damage region always contains one or more validated logical rectangles.
public struct SurfaceFrameMetadata: Equatable, Sendable {
    /// The compositor-facing semantic class of the frame's content.
    public var contentType: SurfaceContentType?
    /// Whether presentation should remain synchronized or may tear.
    public var presentationHint: SurfacePresentationHint?
    /// The multiplier applied to the committed surface's alpha channel.
    public var alpha: SurfaceAlphaMultiplier?
    /// Color-representation facts that accompany the committed buffer.
    public var colorRepresentation: SurfaceColorRepresentation?
    package var colorDescription: SurfaceColorDescriptionReference?
    /// Logical rectangles changed by this frame, or `nil` for the full frame.
    public var damage: SurfaceDamageRegion?

    /// Metadata that requests no optional protocol state and full-frame damage.
    public static let `default` = SurfaceFrameMetadata()

    /// Creates renderer-neutral metadata for one surface frame.
    public init(
        contentType surfaceContentType: SurfaceContentType? = nil,
        presentationHint surfacePresentationHint: SurfacePresentationHint? = nil,
        alpha surfaceAlpha: SurfaceAlphaMultiplier? = nil,
        colorRepresentation surfaceColorRepresentation: SurfaceColorRepresentation? = nil,
        damage surfaceDamage: SurfaceDamageRegion? = nil
    ) {
        contentType = surfaceContentType
        presentationHint = surfacePresentationHint
        alpha = surfaceAlpha
        colorRepresentation = surfaceColorRepresentation
        colorDescription = nil
        damage = surfaceDamage
    }

    package init(
        colorDescription surfaceColorDescription: SurfaceColorDescriptionReference?,
        contentType surfaceContentType: SurfaceContentType? = nil,
        presentationHint surfacePresentationHint: SurfacePresentationHint? = nil,
        alpha surfaceAlpha: SurfaceAlphaMultiplier? = nil,
        colorRepresentation surfaceColorRepresentation: SurfaceColorRepresentation? = nil,
        damage surfaceDamage: SurfaceDamageRegion? = nil
    ) {
        contentType = surfaceContentType
        presentationHint = surfacePresentationHint
        alpha = surfaceAlpha
        colorRepresentation = surfaceColorRepresentation
        colorDescription = surfaceColorDescription
        damage = surfaceDamage
    }
}

/// A semantic content classification supplied to the compositor.
public enum SurfaceContentType: Equatable, Sendable {
    /// No specialized content classification.
    case none
    /// A still photographic image.
    case photo
    /// Moving video content.
    case video
    /// Latency-sensitive game content.
    case game
}

/// A compositor presentation-mode hint for one frame.
public enum SurfacePresentationHint: Equatable, Sendable {
    /// Synchronize presentation to avoid tearing.
    case vsync
    /// Permit asynchronous presentation and tearing.
    case async
}

/// A fixed-point multiplier applied to a surface's alpha channel.
public struct SurfaceAlphaMultiplier: Equatable, Sendable {
    /// The protocol fixed-point representation of the multiplier.
    public let rawValue: UInt32

    /// Fully opaque surface content.
    public static let opaque = Self(rawValue: .max)
    /// Fully transparent surface content.
    public static let transparent = Self(rawValue: 0)

    /// Creates a multiplier from its protocol fixed-point representation.
    public init(rawValue alphaMultiplierRawValue: UInt32) {
        rawValue = alphaMultiplierRawValue
    }
}

/// The alpha interpretation used by a surface color representation.
public enum SurfaceColorAlphaMode: Equatable, Sendable {
    /// Alpha-premultiplied values in electrical space.
    case premultipliedElectrical
    /// Alpha-premultiplied values in optical space.
    case premultipliedOptical
    /// Straight, non-premultiplied alpha values.
    case straight
}

/// Public color-representation facts attached to a surface frame.
public struct SurfaceColorRepresentation: Equatable, Sendable {
    package var storedAlphaMode: SurfaceAlphaMode?
    package var coefficientsAndRange: SurfaceMatrixCoefficientsAndRange?
    package var chromaLocation: SurfaceChromaLocation?

    /// The frame's alpha interpretation, when one is explicitly requested.
    public var alphaMode: SurfaceColorAlphaMode? {
        get { storedAlphaMode?.publicValue }
        set { storedAlphaMode = newValue?.surfaceValue }
    }

    /// Creates a color representation with an optional alpha interpretation.
    public init(alphaMode colorAlphaMode: SurfaceColorAlphaMode? = nil) {
        storedAlphaMode = colorAlphaMode?.surfaceValue
        coefficientsAndRange = nil
        chromaLocation = nil
    }

    package init(
        rawAlphaMode surfaceAlphaMode: SurfaceAlphaMode? = nil,
        coefficientsAndRange surfaceCoefficientsAndRange: SurfaceMatrixCoefficientsAndRange? = nil,
        chromaLocation surfaceChromaLocation: SurfaceChromaLocation? = nil
    ) {
        storedAlphaMode = surfaceAlphaMode
        coefficientsAndRange = surfaceCoefficientsAndRange
        chromaLocation = surfaceChromaLocation
    }
}

/// A typed failure raised before direct window presentation when explicitly
/// requested surface metadata is unsupported by the compositor.
public enum SurfaceFrameMetadataError: Error, Equatable, Sendable,
    CustomStringConvertible
{
    /// The compositor does not expose the content-type protocol.
    case contentTypeUnavailable
    /// The compositor does not expose the tearing-control protocol.
    case presentationHintUnavailable
    /// The compositor does not expose the alpha-modifier protocol.
    case alphaMultiplierUnavailable
    /// The compositor does not expose the color-representation protocol.
    case colorRepresentationUnavailable
    /// Color-representation support discovery has not completed.
    case colorRepresentationSupportPending
    /// The compositor did not advertise the requested color alpha mode.
    case unsupportedColorAlphaMode(SurfaceColorAlphaMode)

    /// Human-readable diagnostic text for the unsupported metadata request.
    public var description: String {
        switch self {
        case .contentTypeUnavailable:
            "content-type protocol is unavailable"
        case .presentationHintUnavailable:
            "tearing-control protocol is unavailable"
        case .alphaMultiplierUnavailable:
            "alpha-modifier protocol is unavailable"
        case .colorRepresentationUnavailable:
            "color-representation protocol is unavailable"
        case .colorRepresentationSupportPending:
            "color-representation support discovery is pending"
        case .unsupportedColorAlphaMode(let alphaMode):
            "color alpha mode \(alphaMode) is not supported by the compositor"
        }
    }
}

extension SurfaceFrameMetadata {
    package var surfaceCommitMetadata: SurfaceCommitMetadata {
        SurfaceCommitMetadata(
            contentType: contentType,
            alpha: alpha.map(SurfaceAlphaMetadata.init(multiplier:)),
            colorRepresentation: colorRepresentation,
            colorDescription: colorDescription,
            presentationHint: presentationHint
        )
    }

    package var hasCommitMetadata: Bool {
        contentType != nil
            || presentationHint != nil
            || alpha != nil
            || colorRepresentation != nil
            || colorDescription != nil
    }

    package func validate(
        capabilities: SurfaceCapabilitySnapshot
    ) throws(SurfaceFrameMetadataError) {
        if contentType != nil, capabilities.contentType == .unavailable {
            throw .contentTypeUnavailable
        }
        if presentationHint != nil, capabilities.tearingControl == .unavailable {
            throw .presentationHintUnavailable
        }
        if alpha != nil, capabilities.alphaModifier == .unavailable {
            throw .alphaMultiplierUnavailable
        }
        guard let colorRepresentation else { return }

        let support: SurfaceColorRepresentationSupport
        switch capabilities.colorRepresentation {
        case .unavailable:
            throw .colorRepresentationUnavailable
        case .pending:
            throw .colorRepresentationSupportPending
        case .available(_, let availableSupport):
            support = availableSupport
        }

        if let alphaMode = colorRepresentation.alphaMode,
            !support.alphaModes.contains(alphaMode.surfaceValue)
        {
            throw .unsupportedColorAlphaMode(alphaMode)
        }
    }
}

extension SurfaceColorAlphaMode {
    package var surfaceValue: SurfaceAlphaMode {
        switch self {
        case .premultipliedElectrical:
            .premultipliedElectrical
        case .premultipliedOptical:
            .premultipliedOptical
        case .straight:
            .straight
        }
    }
}

extension SurfaceAlphaMode {
    package var publicValue: SurfaceColorAlphaMode? {
        if self == .premultipliedElectrical {
            return .premultipliedElectrical
        }
        if self == .premultipliedOptical {
            return .premultipliedOptical
        }
        if self == .straight {
            return .straight
        }
        return nil
    }
}
