import CWaylandProtocols

package func ignoreSurfaceMetadataProxyDestroy() {
    // Optional destruction hook for tests.
}

package enum RawSurfaceMetadataError: Error, Equatable, Sendable, CustomStringConvertible {
    case contentTypeAlreadyExists
    case alphaModifierAlreadyExists
    case tearingControlAlreadyExists
    case colorRepresentationAlreadyExists
    case colorManagementSurfaceAlreadyExists
    case surfaceFeedbackAlreadyExists
    case colorManagementOutputAlreadyExists
    case invalidImageDescriptionIdentity

    package var description: String {
        switch self {
        case .contentTypeAlreadyExists:
            "surface already has a content type object"
        case .alphaModifierAlreadyExists:
            "surface already has an alpha modifier object"
        case .tearingControlAlreadyExists:
            "surface already has a tearing control object"
        case .colorRepresentationAlreadyExists:
            "surface already has a color representation object"
        case .colorManagementSurfaceAlreadyExists:
            "surface already has a color management object"
        case .surfaceFeedbackAlreadyExists:
            "surface already has a color management feedback object"
        case .colorManagementOutputAlreadyExists:
            "output already has a color management object"
        case .invalidImageDescriptionIdentity:
            "image description identity must be nonzero"
        }
    }
}

package struct RawContentType: Equatable, Sendable {
    package let rawValue: UInt32

    package static let none = Self(rawValue: 0)
    package static let photo = Self(rawValue: 1)
    package static let video = Self(rawValue: 2)
    package static let game = Self(rawValue: 3)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package struct RawAlphaMultiplier: Equatable, Sendable {
    package let rawValue: UInt32

    package static let opaque = Self(rawValue: UInt32.max)
    package static let transparent = Self(rawValue: 0)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package enum RawPresentationHint: Equatable, Sendable {
    case vsync
    case async
    case unknown(UInt32)

    package var rawValue: UInt32 {
        switch self {
        case .vsync:
            0
        case .async:
            1
        case .unknown(let value):
            value
        }
    }
}

package struct RawSurfaceAlphaMode: Equatable, Sendable {
    package let rawValue: UInt32

    package static let premultipliedElectrical = Self(rawValue: 0)
    package static let premultipliedOptical = Self(rawValue: 1)
    package static let straight = Self(rawValue: 2)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package struct RawSurfaceMatrixCoefficients: Equatable, Sendable {
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
}

package struct RawSurfaceQuantizationRange: Equatable, Sendable {
    package let rawValue: UInt32

    package static let full = Self(rawValue: 1)
    package static let limited = Self(rawValue: 2)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package struct RawSurfaceChromaLocation: Equatable, Sendable {
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
}

package struct RawSurfaceCoefficientsAndRange: Equatable, Sendable {
    package let coefficients: RawSurfaceMatrixCoefficients
    package let range: RawSurfaceQuantizationRange

    package init(
        coefficients matrixCoefficients: RawSurfaceMatrixCoefficients,
        range quantizationRange: RawSurfaceQuantizationRange
    ) {
        coefficients = matrixCoefficients
        range = quantizationRange
    }
}

package struct RawColorRenderIntent: Equatable, Sendable {
    package let rawValue: UInt32

    package static let perceptual = Self(rawValue: 0)
    package static let relative = Self(rawValue: 1)
    package static let saturation = Self(rawValue: 2)
    package static let absolute = Self(rawValue: 3)
    package static let relativeBlackPointCompensation = Self(rawValue: 4)
    package static let absoluteNoAdaptation = Self(rawValue: 5)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package struct RawImageDescriptionFailureCause: Equatable, Sendable {
    package let rawValue: UInt32

    package static let lowVersion = Self(rawValue: 0)
    package static let unsupported = Self(rawValue: 1)
    package static let operatingSystem = Self(rawValue: 2)
    package static let noOutput = Self(rawValue: 3)
    package static let invalidIdentity = Self(rawValue: UInt32.max)

    package init(rawValue value: UInt32) {
        rawValue = value
    }
}

package enum RawImageDescriptionState: Equatable, Sendable {
    case pending
    case ready(identity: RawImageDescriptionIdentity)
    case failed(cause: RawImageDescriptionFailureCause, message: String)
}

package struct RawImageDescriptionIdentity: Equatable, Hashable, Sendable {
    package let rawValue: UInt64

    package init(_ identity: UInt64) throws(RawSurfaceMetadataError) {
        guard identity != 0 else {
            throw .invalidImageDescriptionIdentity
        }

        rawValue = identity
    }
}
