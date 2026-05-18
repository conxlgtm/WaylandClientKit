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

        return .available(version: manager.version)
    }

    package var surfaceColorCapability: SurfaceColorCapability {
        guard let manager = colorManager.boundObject else {
            return .unavailable
        }

        return .available(version: manager.version)
    }
}
