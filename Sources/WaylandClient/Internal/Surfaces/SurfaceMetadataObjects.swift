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

    func apply(_ metadata: SurfaceCommitMetadata) throws(SurfaceCommitMetadataError) {
        if let contentType = metadata.contentType {
            guard let object = self.contentType else {
                throw .contentTypeObjectUnavailable
            }
            object.setContentType(contentType.rawContentType)
        }

        if let alpha = metadata.alpha {
            guard let object = alphaModifier else {
                throw .alphaModifierObjectUnavailable
            }
            object.setMultiplier(alpha.multiplier.rawMultiplier)
        }

        if let presentationHint = metadata.presentationHint {
            guard let object = tearingControl else {
                throw .tearingControlObjectUnavailable
            }
            object.setPresentationHint(presentationHint.rawPresentationHint)
        }

        if let colorRepresentation = metadata.colorRepresentation {
            try apply(colorRepresentation)
        }

        if let colorDescription = metadata.colorDescription {
            try apply(colorDescription)
        }
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

    private func apply(_ representation: SurfaceColorRepresentation)
        throws(SurfaceCommitMetadataError)
    {
        guard let object = colorRepresentation else {
            throw .colorRepresentationObjectUnavailable
        }

        if let alphaMode = representation.alphaMode {
            object.setAlphaMode(alphaMode.rawAlphaMode)
        }
        if let coefficientsAndRange = representation.coefficientsAndRange {
            object.setCoefficientsAndRange(
                coefficientsAndRange.rawCoefficientsAndRange
            )
        }
        if let chromaLocation = representation.chromaLocation {
            object.setChromaLocation(chromaLocation.rawChromaLocation)
        }
    }

    private func apply(_ reference: SurfaceColorDescriptionReference)
        throws(SurfaceCommitMetadataError)
    {
        guard let colorManagement else {
            throw .colorManagementObjectUnavailable
        }
        guard let imageDescription = colorDescriptions[reference] else {
            throw .colorDescriptionUnavailable(reference)
        }

        colorManagement.setImageDescription(imageDescription, renderIntent: .perceptual)
    }
}
