import WaylandRaw

extension SurfaceRuntime {
    var hasContentTypeObject: Bool {
        surfaceObjects?.metadataObjects.hasContentType ?? false
    }

    var hasAlphaModifierObject: Bool {
        surfaceObjects?.metadataObjects.hasAlphaModifier ?? false
    }

    var hasTearingControlObject: Bool {
        surfaceObjects?.metadataObjects.hasTearingControl ?? false
    }

    var hasColorRepresentationObject: Bool {
        surfaceObjects?.metadataObjects.hasColorRepresentation ?? false
    }

    var hasColorManagementObject: Bool {
        surfaceObjects?.metadataObjects.hasColorManagement ?? false
    }

    func hasColorDescription(
        _ reference: SurfaceColorDescriptionReference
    ) -> Bool {
        surfaceObjects?.metadataObjects.hasColorDescription(reference) ?? false
    }

    func tracksColorDescription(
        _ reference: SurfaceColorDescriptionReference
    ) -> Bool {
        surfaceObjects?.metadataObjects.tracksColorDescription(reference) ?? false
    }

    mutating func setContentTypeCapability(_ capability: SurfaceCapabilityStatus) {
        contentTypeCapability = capability
    }

    mutating func setAlphaModifierCapability(_ capability: SurfaceCapabilityStatus) {
        alphaModifierCapability = capability
    }

    mutating func setTearingControlCapability(_ capability: SurfaceCapabilityStatus) {
        tearingControlCapability = capability
    }

    mutating func setColorRepresentationCapability(
        _ capability: SurfaceColorRepresentationCapability
    ) {
        colorRepresentationCapability = capability
    }

    mutating func setColorCapability(_ capability: SurfaceColorCapability) {
        colorCapability = capability
    }

    mutating func installContentTypeObject(_ contentType: RawContentTypeSurface) {
        updateSurfaceObjects { objects in
            objects.metadataObjects.installContentType(contentType)
        }
    }

    mutating func installAlphaModifierObject(_ alphaModifier: RawAlphaModifierSurface) {
        updateSurfaceObjects { objects in
            objects.metadataObjects.installAlphaModifier(alphaModifier)
        }
    }

    mutating func installTearingControlObject(_ tearingControl: RawTearingControl) {
        updateSurfaceObjects { objects in
            objects.metadataObjects.installTearingControl(tearingControl)
        }
    }

    mutating func installColorRepresentationObject(
        _ colorRepresentation: RawColorRepresentationSurface
    ) {
        updateSurfaceObjects { objects in
            objects.metadataObjects.installColorRepresentation(colorRepresentation)
        }
    }

    mutating func installColorManagementObject(
        _ colorManagement: RawColorManagementSurface
    ) {
        updateSurfaceObjects { objects in
            objects.metadataObjects.installColorManagement(colorManagement)
        }
    }

    mutating func installColorDescription(
        _ imageDescription: RawImageDescription,
        reference: SurfaceColorDescriptionReference
    ) {
        updateSurfaceObjects { objects in
            objects.metadataObjects.installColorDescription(
                imageDescription,
                reference: reference
            )
        }
    }

    mutating func resolveColorDescriptionIfNeeded(
        _ reference: SurfaceColorDescriptionReference,
        using manager: RawColorManager,
        surface: RawSurface
    ) throws {
        guard !tracksColorDescription(reference) else { return }

        let feedback = try manager.surfaceFeedback(for: surface)
        defer { feedback.destroy() }

        installColorDescription(
            try feedback.preferredImageDescription(),
            reference: reference
        )
    }

    mutating func applyCommitMetadata(
        _ metadata: SurfaceCommitMetadata
    ) throws(SurfaceCommitMetadataError) {
        guard let objects = surfaceObjects else { return }
        try objects.metadataObjects.apply(metadata)
    }

    func preflightCommitMetadata(
        _ metadata: SurfaceCommitMetadata
    ) throws(SurfaceCommitMetadataError) {
        guard let objects = surfaceObjects else { return }
        _ = try objects.metadataObjects.preflight(metadata)
    }
}
