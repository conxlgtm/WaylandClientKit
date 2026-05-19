import WaylandRaw

struct SurfaceMetadataObjects {
    private var contentType: RawContentTypeSurface?
    private var alphaModifier: RawAlphaModifierSurface?
    private var tearingControl: RawTearingControl?
    private var colorRepresentation: RawColorRepresentationSurface?
    private var colorManagement: RawColorManagementSurface?
    private var colorDescriptions: [SurfaceColorDescriptionReference: RawImageDescription] =
        [:]

    var hasContentType: Bool {
        contentType != nil
    }

    var hasAlphaModifier: Bool {
        alphaModifier != nil
    }

    var hasTearingControl: Bool {
        tearingControl != nil
    }

    var hasColorRepresentation: Bool {
        colorRepresentation != nil
    }

    var hasColorManagement: Bool {
        colorManagement != nil
    }

    mutating func installContentType(_ newContentType: RawContentTypeSurface) {
        contentType?.destroy()
        contentType = newContentType
    }

    mutating func installAlphaModifier(_ newAlphaModifier: RawAlphaModifierSurface) {
        alphaModifier?.destroy()
        alphaModifier = newAlphaModifier
    }

    mutating func installTearingControl(_ newTearingControl: RawTearingControl) {
        tearingControl?.destroy()
        tearingControl = newTearingControl
    }

    mutating func installColorRepresentation(
        _ newColorRepresentation: RawColorRepresentationSurface
    ) {
        colorRepresentation?.destroy()
        colorRepresentation = newColorRepresentation
    }

    mutating func installColorManagement(_ newColorManagement: RawColorManagementSurface) {
        colorManagement?.destroy()
        colorManagement = newColorManagement
    }

    mutating func installColorDescription(
        _ imageDescription: RawImageDescription,
        reference: SurfaceColorDescriptionReference
    ) {
        colorDescriptions[reference]?.destroy()
        colorDescriptions[reference] = imageDescription
    }

    func preflight(_ metadata: SurfaceCommitMetadata)
        throws(SurfaceCommitMetadataError) -> ResolvedSurfaceCommitMetadata
    {
        var resolved = ResolvedSurfaceCommitMetadata()

        if let contentType = metadata.contentType {
            guard let object = self.contentType else {
                throw .contentTypeObjectUnavailable
            }
            resolved.contentType = (object, contentType.rawContentType)
        }

        if let alpha = metadata.alpha {
            guard let object = alphaModifier else {
                throw .alphaModifierObjectUnavailable
            }
            resolved.alpha = (object, alpha.multiplier.rawMultiplier)
        }

        if let presentationHint = metadata.presentationHint {
            guard let object = tearingControl else {
                throw .tearingControlObjectUnavailable
            }
            resolved.presentationHint = (object, presentationHint.rawPresentationHint)
        }

        if let colorRepresentation = metadata.colorRepresentation {
            resolved.colorRepresentation = try preflight(colorRepresentation)
        }

        if let colorDescription = metadata.colorDescription {
            resolved.colorDescription = try preflight(colorDescription)
        }

        return resolved
    }

    func apply(_ metadata: SurfaceCommitMetadata) throws(SurfaceCommitMetadataError) {
        try preflight(metadata).apply()
    }

    mutating func destroy() {
        for imageDescription in colorDescriptions.values {
            imageDescription.destroy()
        }
        colorDescriptions.removeAll(keepingCapacity: false)

        colorManagement?.destroy()
        colorManagement = nil

        colorRepresentation?.destroy()
        colorRepresentation = nil

        tearingControl?.destroy()
        tearingControl = nil

        alphaModifier?.destroy()
        alphaModifier = nil

        contentType?.destroy()
        contentType = nil
    }

    private func preflight(_ representation: SurfaceColorRepresentation)
        throws(SurfaceCommitMetadataError) -> ResolvedSurfaceColorRepresentation
    {
        guard let object = colorRepresentation else {
            throw .colorRepresentationObjectUnavailable
        }

        return ResolvedSurfaceColorRepresentation(
            object: object,
            alphaMode: representation.alphaMode?.rawAlphaMode,
            coefficientsAndRange:
                representation.coefficientsAndRange?.rawCoefficientsAndRange,
            chromaLocation: representation.chromaLocation?.rawChromaLocation
        )
    }

    private func preflight(_ reference: SurfaceColorDescriptionReference)
        throws(SurfaceCommitMetadataError)
        -> (RawColorManagementSurface, RawImageDescription)
    {
        guard let colorManagement else {
            throw .colorManagementObjectUnavailable
        }
        guard let imageDescription = colorDescriptions[reference] else {
            throw .colorDescriptionUnavailable(reference)
        }

        return (colorManagement, imageDescription)
    }
}

struct ResolvedSurfaceCommitMetadata {
    var contentType: (RawContentTypeSurface, RawContentType)?
    var alpha: (RawAlphaModifierSurface, RawAlphaMultiplier)?
    var presentationHint: (RawTearingControl, RawPresentationHint)?
    var colorRepresentation: ResolvedSurfaceColorRepresentation?
    var colorDescription: (RawColorManagementSurface, RawImageDescription)?

    func apply() {
        if let contentType {
            contentType.0.setContentType(contentType.1)
        }
        if let alpha {
            alpha.0.setMultiplier(alpha.1)
        }
        if let presentationHint {
            presentationHint.0.setPresentationHint(presentationHint.1)
        }
        colorRepresentation?.apply()
        if let colorDescription {
            colorDescription.0.setImageDescription(
                colorDescription.1,
                renderIntent: .perceptual
            )
        }
    }
}

struct ResolvedSurfaceColorRepresentation {
    let object: RawColorRepresentationSurface
    let alphaMode: RawSurfaceAlphaMode?
    let coefficientsAndRange: RawSurfaceCoefficientsAndRange?
    let chromaLocation: RawSurfaceChromaLocation?

    func apply() {
        if let alphaMode {
            object.setAlphaMode(alphaMode)
        }
        if let coefficientsAndRange {
            object.setCoefficientsAndRange(coefficientsAndRange)
        }
        if let chromaLocation {
            object.setChromaLocation(chromaLocation)
        }
    }
}
