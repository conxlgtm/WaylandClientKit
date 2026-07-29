import WaylandRaw

enum SurfaceMetadataSupport {
    static func refreshCapabilities<RoleResources>(
        connection: RawDisplayConnection,
        runtime: inout SurfaceRuntime<RoleResources>
    ) {
        guard let extensions = connection.boundGlobals?.extensions else {
            runtime.setContentTypeCapability(.unavailable)
            runtime.setAlphaModifierCapability(.unavailable)
            runtime.setTearingControlCapability(.unavailable)
            runtime.setColorRepresentationCapability(.unavailable)
            runtime.setColorCapability(.unavailable)
            return
        }

        runtime.setContentTypeCapability(extensions.surfaceContentTypeCapability)
        runtime.setAlphaModifierCapability(extensions.surfaceAlphaModifierCapability)
        runtime.setTearingControlCapability(extensions.surfaceTearingControlCapability)
        runtime.setColorRepresentationCapability(
            extensions.surfaceColorRepresentationCapability
        )
        runtime.setColorCapability(extensions.surfaceColorCapability)
    }

    static func validate<RoleResources>(
        _ metadata: SurfaceFrameMetadata,
        connection: RawDisplayConnection,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws {
        refreshCapabilities(connection: connection, runtime: &runtime)
        try metadata.validate(capabilities: runtime.capabilitySnapshot())
    }

    static func ensureObjectsInstalled<RoleResources>(
        for metadata: SurfaceCommitMetadata,
        connection: RawDisplayConnection,
        surface: RawSurface,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws {
        if metadata.contentType != nil {
            try ensureContentTypeObjectInstalled(
                connection: connection,
                surface: surface,
                runtime: &runtime
            )
        }
        if metadata.alpha != nil {
            try ensureAlphaModifierObjectInstalled(
                connection: connection,
                surface: surface,
                runtime: &runtime
            )
        }
        if metadata.presentationHint != nil {
            try ensureTearingControlObjectInstalled(
                connection: connection,
                surface: surface,
                runtime: &runtime
            )
        }
        if metadata.colorRepresentation != nil {
            try ensureColorRepresentationObjectInstalled(
                connection: connection,
                surface: surface,
                runtime: &runtime
            )
        }
        if let colorDescription = metadata.colorDescription {
            try ensureColorManagementObjectInstalled(
                connection: connection,
                surface: surface,
                runtime: &runtime
            )
            try ensureColorDescriptionInstalled(
                colorDescription,
                connection: connection,
                surface: surface,
                runtime: &runtime
            )
        }
    }
}

extension SurfaceMetadataSupport {
    private static func ensureContentTypeObjectInstalled<RoleResources>(
        connection: RawDisplayConnection,
        surface: RawSurface,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws {
        guard !runtime.hasContentTypeObject else { return }
        guard let manager = connection.boundGlobals?.extensions.contentTypeManager.boundObject
        else { throw SurfaceCommitMetadataError.contentTypeUnavailable }
        runtime.installContentTypeObject(try manager.contentType(for: surface))
    }

    private static func ensureAlphaModifierObjectInstalled<RoleResources>(
        connection: RawDisplayConnection,
        surface: RawSurface,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws {
        guard !runtime.hasAlphaModifierObject else { return }
        guard let manager = connection.boundGlobals?.extensions.alphaModifierManager.boundObject
        else { throw SurfaceCommitMetadataError.alphaModifierUnavailable }
        runtime.installAlphaModifierObject(try manager.alphaModifier(for: surface))
    }

    private static func ensureTearingControlObjectInstalled<RoleResources>(
        connection: RawDisplayConnection,
        surface: RawSurface,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws {
        guard !runtime.hasTearingControlObject else { return }
        guard let manager = connection.boundGlobals?.extensions.tearingControlManager.boundObject
        else { throw SurfaceCommitMetadataError.tearingControlUnavailable }
        runtime.installTearingControlObject(try manager.tearingControl(for: surface))
    }

    private static func ensureColorRepresentationObjectInstalled<RoleResources>(
        connection: RawDisplayConnection,
        surface: RawSurface,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws {
        runtime.setColorRepresentationCapability(
            connection.boundGlobals?.extensions.surfaceColorRepresentationCapability
                ?? .unavailable
        )
        guard !runtime.hasColorRepresentationObject else { return }
        guard
            let manager = connection.boundGlobals?.extensions.colorRepresentationManager.boundObject
        else { throw SurfaceCommitMetadataError.colorRepresentationUnavailable }
        runtime.installColorRepresentationObject(try manager.colorRepresentation(for: surface))
    }

    private static func ensureColorManagementObjectInstalled<RoleResources>(
        connection: RawDisplayConnection,
        surface: RawSurface,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws {
        guard !runtime.hasColorManagementObject else { return }
        guard let manager = connection.boundGlobals?.extensions.colorManager.boundObject
        else { throw SurfaceCommitMetadataError.colorUnavailable }
        runtime.installColorManagementObject(try manager.surface(for: surface))
    }

    private static func ensureColorDescriptionInstalled<RoleResources>(
        _ reference: SurfaceColorDescriptionReference,
        connection: RawDisplayConnection,
        surface: RawSurface,
        runtime: inout SurfaceRuntime<RoleResources>
    ) throws {
        guard !runtime.hasColorDescription(reference) else { return }
        guard let manager = connection.boundGlobals?.extensions.colorManager.boundObject
        else { throw SurfaceCommitMetadataError.colorUnavailable }
        try runtime.resolveColorDescriptionIfNeeded(
            reference,
            using: manager,
            surface: surface
        )
    }
}
