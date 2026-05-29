import CWaylandProtocols

package struct RawManagedSubsurfaceObjects {
    package let surface: RawSurface
    package let subsurface: RawSubsurface
}

extension RawDisplayConnection {
    @safe
    package func createManagedSubsurface(
        parent parentSurface: RawSurface
    ) throws -> RawManagedSubsurfaceObjects {
        preconditionIsOwnerThread()

        let globals = try bindRequiredGlobals()
        let childSurface = try globals.compositor.createSurface()

        do {
            let subcompositor = try bindSubcompositorOneShot()
            defer { subcompositor.destroy() }

            let subsurface = try subcompositor.getSubsurface(
                surface: childSurface,
                parent: parentSurface
            )
            return RawManagedSubsurfaceObjects(
                surface: childSurface,
                subsurface: subsurface
            )
        } catch {
            childSurface.destroy()
            throw error
        }
    }

    @safe
    private func bindSubcompositorOneShot() throws -> RawSubcompositor {
        guard let global = optionalGlobal(named: "wl_subcompositor") else {
            throw RuntimeError.missingRequiredGlobal("wl_subcompositor")
        }

        let version = global.negotiatedVersion(
            supportedByClient: SupportedVersions.wlSubcompositor
        )
        guard
            let subcompositor = unsafe swl_registry_bind_wl_subcompositor(
                registry.opaquePointer,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wl_subcompositor")
        }

        return try RawSubcompositor(
            pointer: subcompositor,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }
}
