import CWaylandProtocols

package final class RawTearingControlManager {
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
            interface: "wp_tearing_control_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_tearing_control_manager_v1_destroy
        )
    }

    package func tearingControl(for surface: RawSurface) throws(RuntimeError)
        -> RawTearingControl
    {
        let surfaceID = surface.objectID
        guard !surfaceIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(
                RawSurfaceMetadataError.tearingControlAlreadyExists.description
            )
        }

        guard
            let tearingControl =
                unsafe swl_wp_tearing_control_manager_v1_get_tearing_control(
                    pointer,
                    surface.pointer
                )
        else {
            throw RuntimeError.bindFailed("wp_tearing_control_v1")
        }

        let adoptedTearingControl = try unsafe proxyAdoption.adoptOrDestroy(
            tearingControl,
            interface: "wp_tearing_control_v1",
            destroy: unsafe swl_wp_tearing_control_v1_destroy
        )
        surfaceIDs.insert(surfaceID)
        return RawTearingControl(
            pointer: adoptedTearingControl,
            destroy: unsafe swl_wp_tearing_control_v1_destroy
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
package final class RawTearingControl {
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer tearingControlPointer: OpaquePointer,
        destroy destroyTearingControl: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = ignoreSurfaceMetadataProxyDestroy
    ) {
        proxy = RawOwnedProxy(
            pointer: tearingControlPointer,
            destroy: destroyTearingControl
        )
        onDestroy = handleDestroy
    }

    package func setPresentationHint(_ hint: RawPresentationHint) {
        unsafe swl_wp_tearing_control_v1_set_presentation_hint(pointer, hint.rawValue)
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
