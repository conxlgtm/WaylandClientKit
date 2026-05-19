import CWaylandProtocols

package final class RawAlphaModifierManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy
    private var surfaceIDs: Set<RawObjectID> = []

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = managerVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "wp_alpha_modifier_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_alpha_modifier_v1_destroy
        )
    }

    package func alphaModifier(for surface: RawSurface) throws(RuntimeError)
        -> RawAlphaModifierSurface
    {
        let surfaceID = surface.objectID
        guard !surfaceIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(
                RawSurfaceMetadataError.alphaModifierAlreadyExists.description
            )
        }

        guard
            let alphaModifier = unsafe swl_wp_alpha_modifier_v1_get_surface(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("wp_alpha_modifier_surface_v1")
        }

        let adoptedSurface = try unsafe proxyAdoption.adoptOrDestroy(
            alphaModifier,
            interface: "wp_alpha_modifier_surface_v1",
            destroy: unsafe swl_wp_alpha_modifier_surface_v1_destroy
        )
        surfaceIDs.insert(surfaceID)
        return RawAlphaModifierSurface(
            pointer: adoptedSurface,
            destroy: unsafe swl_wp_alpha_modifier_surface_v1_destroy
        ) { [weak self] in
            self?.surfaceIDs.remove(surfaceID)
        }
    }

    package func destroy() {
        surfaceIDs.removeAll(keepingCapacity: false)
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawAlphaModifierSurface {
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer surfacePointer: OpaquePointer,
        destroy destroySurface: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = ignoreSurfaceMetadataProxyDestroy
    ) {
        proxy = RawOwnedProxy(pointer: surfacePointer, destroy: destroySurface)
        onDestroy = handleDestroy
    }

    package func setMultiplier(_ multiplier: RawAlphaMultiplier) {
        unsafe swl_wp_alpha_modifier_surface_v1_set_multiplier(
            pointer,
            multiplier.rawValue
        )
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        proxy.destroy()
        onDestroy()
    }

    deinit {
        destroy()
    }
}
