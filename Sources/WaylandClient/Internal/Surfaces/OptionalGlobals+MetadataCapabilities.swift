import WaylandRaw

extension OptionalGlobals {
    package var surfaceContentTypeCapability: SurfaceCapabilityStatus {
        contentTypeManager.isBound ? .available : .unavailable
    }

    package var surfaceAlphaModifierCapability: SurfaceCapabilityStatus {
        alphaModifierManager.isBound ? .available : .unavailable
    }

    package var surfaceTearingControlCapability: SurfaceCapabilityStatus {
        tearingControlManager.isBound ? .available : .unavailable
    }

    package var surfaceColorRepresentationCapability: SurfaceColorRepresentationCapability {
        guard let manager = colorRepresentationManager.boundObject else {
            return .unavailable
        }

        return .available(
            version: manager.version,
            supportedAlphaModes: Set(
                manager.supportedAlphaModes.map { alphaMode in
                    SurfaceAlphaMode(rawValue: alphaMode.rawValue)
                }
            ),
            supportedCoefficientsAndRanges: Set(
                manager.supportedCoefficientsAndRanges.map { coefficientsAndRange in
                    SurfaceMatrixCoefficientsAndRange(
                        coefficients: SurfaceMatrixCoefficients(
                            rawValue: coefficientsAndRange.coefficients.rawValue
                        ),
                        range: SurfaceQuantizationRange(
                            rawValue: coefficientsAndRange.range.rawValue
                        )
                    )
                }
            )
        )
    }

    package var surfaceColorCapability: SurfaceColorCapability {
        guard let manager = colorManager.boundObject else {
            return .unavailable
        }

        return .available(version: manager.version)
    }
}
