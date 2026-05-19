import WaylandRaw

package struct SurfaceContentType: Equatable, Hashable, Sendable {
    package let rawValue: UInt32

    package static let none = Self(rawValue: 0)
    package static let photo = Self(rawValue: 1)
    package static let video = Self(rawValue: 2)
    package static let game = Self(rawValue: 3)

    package init(rawValue value: UInt32) {
        rawValue = value
    }

    var rawContentType: RawContentType {
        RawContentType(rawValue: rawValue)
    }

    var isValidOutboundValue: Bool {
        Self.validOutboundValues.contains(self)
    }

    private static let validOutboundValues: Set<Self> = [
        .none,
        .photo,
        .video,
        .game,
    ]
}

package struct SurfaceAlphaMultiplier: Equatable, Sendable {
    package let rawValue: UInt32

    package static let opaque = Self(rawValue: UInt32.max)
    package static let transparent = Self(rawValue: 0)

    package init(rawValue value: UInt32) {
        rawValue = value
    }

    var rawMultiplier: RawAlphaMultiplier {
        RawAlphaMultiplier(rawValue: rawValue)
    }
}

package struct SurfaceAlphaMetadata: Equatable, Sendable {
    package var multiplier: SurfaceAlphaMultiplier

    package init(multiplier alphaMultiplier: SurfaceAlphaMultiplier = .opaque) {
        multiplier = alphaMultiplier
    }
}

package enum SurfacePresentationHint: Equatable, Sendable {
    case vsync
    case async

    var rawPresentationHint: RawPresentationHint {
        switch self {
        case .vsync:
            .vsync
        case .async:
            .async
        }
    }
}

package struct SurfaceAlphaMode: Equatable, Hashable, Sendable {
    package let rawValue: UInt32

    package static let premultipliedElectrical = Self(rawValue: 0)
    package static let premultipliedOptical = Self(rawValue: 1)
    package static let straight = Self(rawValue: 2)

    package init(rawValue value: UInt32) {
        rawValue = value
    }

    var rawAlphaMode: RawSurfaceAlphaMode {
        RawSurfaceAlphaMode(rawValue: rawValue)
    }
}

package struct SurfaceMatrixCoefficients: Equatable, Hashable, Sendable {
    package let rawValue: UInt32

    package static let identity = Self(rawValue: 1)
    package static let bt709 = Self(rawValue: 2)
    package static let fcc = Self(rawValue: 3)
    package static let bt601 = Self(rawValue: 4)
    package static let smpte240 = Self(rawValue: 5)
    package static let bt2020 = Self(rawValue: 6)
    package static let bt2020ConstantLuminance = Self(rawValue: 7)
    package static let ictcp = Self(rawValue: 8)

    package init(rawValue value: UInt32) {
        rawValue = value
    }

    var rawCoefficients: RawSurfaceMatrixCoefficients {
        RawSurfaceMatrixCoefficients(rawValue: rawValue)
    }
}

package struct SurfaceQuantizationRange: Equatable, Hashable, Sendable {
    package let rawValue: UInt32

    package static let full = Self(rawValue: 1)
    package static let limited = Self(rawValue: 2)

    package init(rawValue value: UInt32) {
        rawValue = value
    }

    var rawRange: RawSurfaceQuantizationRange {
        RawSurfaceQuantizationRange(rawValue: rawValue)
    }
}

package struct SurfaceMatrixCoefficientsAndRange: Equatable, Hashable, Sendable {
    package var coefficients: SurfaceMatrixCoefficients
    package var range: SurfaceQuantizationRange

    package init(
        coefficients matrixCoefficients: SurfaceMatrixCoefficients,
        range quantizationRange: SurfaceQuantizationRange
    ) {
        coefficients = matrixCoefficients
        range = quantizationRange
    }

    var rawCoefficientsAndRange: RawSurfaceCoefficientsAndRange {
        RawSurfaceCoefficientsAndRange(
            coefficients: coefficients.rawCoefficients,
            range: range.rawRange
        )
    }
}

package struct SurfaceChromaLocation: Equatable, Hashable, Sendable {
    package let rawValue: UInt32

    package static let type0 = Self(rawValue: 1)
    package static let type1 = Self(rawValue: 2)
    package static let type2 = Self(rawValue: 3)
    package static let type3 = Self(rawValue: 4)
    package static let type4 = Self(rawValue: 5)
    package static let type5 = Self(rawValue: 6)

    package init(rawValue value: UInt32) {
        rawValue = value
    }

    var rawChromaLocation: RawSurfaceChromaLocation {
        RawSurfaceChromaLocation(rawValue: rawValue)
    }

    var isValidOutboundValue: Bool {
        Self.validOutboundValues.contains(self)
    }

    private static let validOutboundValues: Set<Self> = [
        .type0,
        .type1,
        .type2,
        .type3,
        .type4,
        .type5,
    ]
}

package struct SurfaceColorRepresentation: Equatable, Sendable {
    package var alphaMode: SurfaceAlphaMode?
    package var coefficientsAndRange: SurfaceMatrixCoefficientsAndRange?
    package var chromaLocation: SurfaceChromaLocation?

    package init(
        alphaMode surfaceAlphaMode: SurfaceAlphaMode? = nil,
        coefficientsAndRange surfaceCoefficientsAndRange:
            SurfaceMatrixCoefficientsAndRange? = nil,
        chromaLocation surfaceChromaLocation: SurfaceChromaLocation? = nil
    ) {
        alphaMode = surfaceAlphaMode
        coefficientsAndRange = surfaceCoefficientsAndRange
        chromaLocation = surfaceChromaLocation
    }
}

package struct SurfaceColorDescriptionReference: Equatable, Hashable, Sendable {
    package let identity: UInt64

    package init(identity referenceIdentity: UInt64) {
        identity = referenceIdentity
    }
}

package struct SurfaceCommitMetadata: Equatable, Sendable {
    package var contentType: SurfaceContentType?
    package var alpha: SurfaceAlphaMetadata?
    package var colorRepresentation: SurfaceColorRepresentation?
    package var colorDescription: SurfaceColorDescriptionReference?
    package var presentationHint: SurfacePresentationHint?

    package static let `default` = Self()

    package init(
        contentType surfaceContentType: SurfaceContentType? = nil,
        alpha surfaceAlpha: SurfaceAlphaMetadata? = nil,
        colorRepresentation surfaceColorRepresentation:
            SurfaceColorRepresentation? = nil,
        colorDescription surfaceColorDescription:
            SurfaceColorDescriptionReference? = nil,
        presentationHint surfacePresentationHint: SurfacePresentationHint? = nil
    ) {
        contentType = surfaceContentType
        alpha = surfaceAlpha
        colorRepresentation = surfaceColorRepresentation
        colorDescription = surfaceColorDescription
        presentationHint = surfacePresentationHint
    }

    func validate(capabilities: SurfaceCapabilitySnapshot)
        throws(SurfaceCommitMetadataError)
    {
        if contentType != nil, capabilities.contentType == .unavailable {
            throw .contentTypeUnavailable
        }
        if let contentType, !contentType.isValidOutboundValue {
            throw .unsupportedContentType(contentType)
        }
        if alpha != nil, capabilities.alphaModifier == .unavailable {
            throw .alphaModifierUnavailable
        }
        if presentationHint != nil, capabilities.tearingControl == .unavailable {
            throw .tearingControlUnavailable
        }
        if let colorRepresentation {
            try colorRepresentation.validate(
                capabilities: capabilities.colorRepresentation
            )
        }
        if colorDescription != nil, !capabilities.color.isAvailable {
            throw .colorUnavailable
        }
    }
}

extension SurfaceColorRepresentation {
    func validate(
        capabilities: SurfaceColorRepresentationCapability
    ) throws(SurfaceCommitMetadataError) {
        guard
            case .available(
                _,
                let support
            ) = capabilities
        else {
            if case .pending = capabilities {
                throw .colorRepresentationSupportPending
            }
            throw .colorRepresentationUnavailable
        }

        if let alphaMode, !support.alphaModes.contains(alphaMode) {
            throw .unsupportedAlphaMode(alphaMode)
        }
        if let coefficientsAndRange,
            !support.coefficientsAndRanges.contains(coefficientsAndRange)
        {
            throw .unsupportedCoefficientsAndRange(coefficientsAndRange)
        }
        if let chromaLocation, !chromaLocation.isValidOutboundValue {
            throw .unsupportedChromaLocation(chromaLocation)
        }
    }
}

package enum SurfaceCommitMetadataError: Error, Equatable, Sendable,
    CustomStringConvertible
{
    case contentTypeUnavailable
    case alphaModifierUnavailable
    case tearingControlUnavailable
    case colorRepresentationUnavailable
    case colorRepresentationSupportPending
    case colorUnavailable
    case contentTypeObjectUnavailable
    case alphaModifierObjectUnavailable
    case tearingControlObjectUnavailable
    case colorRepresentationObjectUnavailable
    case colorManagementObjectUnavailable
    case colorDescriptionUnavailable(SurfaceColorDescriptionReference)
    case unsupportedContentType(SurfaceContentType)
    case unsupportedAlphaMode(SurfaceAlphaMode)
    case unsupportedCoefficientsAndRange(SurfaceMatrixCoefficientsAndRange)
    case unsupportedChromaLocation(SurfaceChromaLocation)

    package var description: String {
        switch self {
        case .contentTypeUnavailable:
            "content-type protocol is unavailable"
        case .alphaModifierUnavailable:
            "alpha-modifier protocol is unavailable"
        case .tearingControlUnavailable:
            "tearing-control protocol is unavailable"
        case .colorRepresentationUnavailable:
            "color-representation protocol is unavailable"
        case .colorRepresentationSupportPending:
            "color-representation support discovery is pending"
        case .colorUnavailable:
            "color-management protocol is unavailable"
        case .contentTypeObjectUnavailable:
            "content type surface object is unavailable"
        case .alphaModifierObjectUnavailable:
            "alpha modifier surface object is unavailable"
        case .tearingControlObjectUnavailable:
            "tearing control surface object is unavailable"
        case .colorRepresentationObjectUnavailable:
            "color representation surface object is unavailable"
        case .colorManagementObjectUnavailable:
            "color management surface object is unavailable"
        case .colorDescriptionUnavailable(let reference):
            "color description \(reference.identity) is unavailable"
        case .unsupportedContentType(let contentType):
            "content type \(contentType.rawValue) is not supported for outbound commits"
        case .unsupportedAlphaMode(let alphaMode):
            "alpha mode \(alphaMode.rawValue) is not supported by the compositor"
        case .unsupportedCoefficientsAndRange(let coefficientsAndRange):
            "coefficients \(coefficientsAndRange.coefficients.rawValue) range "
                + "\(coefficientsAndRange.range.rawValue) is not supported by the compositor"
        case .unsupportedChromaLocation(let chromaLocation):
            "chroma location \(chromaLocation.rawValue) is not supported for outbound commits"
        }
    }
}
