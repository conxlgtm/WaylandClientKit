import WaylandRaw

extension SurfaceRuntime {
    var hasContentTypeObject: Bool {
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            objects.metadataObjects.hasContentType
        case .surfaceDestroyed:
            false
        }
    }

    var hasAlphaModifierObject: Bool {
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            objects.metadataObjects.hasAlphaModifier
        case .surfaceDestroyed:
            false
        }
    }

    var hasTearingControlObject: Bool {
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            objects.metadataObjects.hasTearingControl
        case .surfaceDestroyed:
            false
        }
    }

    var hasColorRepresentationObject: Bool {
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            objects.metadataObjects.hasColorRepresentation
        case .surfaceDestroyed:
            false
        }
    }

    var hasColorManagementObject: Bool {
        switch phase {
        case .unassigned(let objects),
            .live(_, let objects),
            .roleDestroyed(let objects):
            objects.metadataObjects.hasColorManagement
        case .surfaceDestroyed:
            false
        }
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

    mutating func applyCommitMetadata(
        _ metadata: SurfaceCommitMetadata
    ) throws(SurfaceCommitMetadataError) {
        switch phase {
        case .unassigned(let objects):
            try objects.metadataObjects.apply(metadata)
        case .live(_, let objects):
            try objects.metadataObjects.apply(metadata)
        case .roleDestroyed(let objects):
            try objects.metadataObjects.apply(metadata)
        case .surfaceDestroyed:
            return
        }
    }
}
