import CWaylandProtocols

package final class RawContentTypeManager {
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
            interface: "wp_content_type_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_content_type_manager_v1_destroy
        )
    }

    package func contentType(for surface: RawSurface) throws(RuntimeError)
        -> RawContentTypeSurface
    {
        let surfaceID = surface.objectID
        guard !surfaceIDs.contains(surfaceID) else {
            throw RuntimeError.invalidArgument(
                RawSurfaceMetadataError.contentTypeAlreadyExists.description
            )
        }

        guard
            let contentType = unsafe swl_wp_content_type_manager_v1_get_surface_content_type(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("wp_content_type_v1")
        }

        let adoptedContentType = try unsafe proxyAdoption.adoptOrDestroy(
            contentType,
            interface: "wp_content_type_v1",
            destroy: unsafe swl_wp_content_type_v1_destroy
        )
        surfaceIDs.insert(surfaceID)
        return RawContentTypeSurface(
            pointer: adoptedContentType,
            destroy: unsafe swl_wp_content_type_v1_destroy
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
package final class RawContentTypeSurface {
    private var proxy: RawOwnedProxy
    private let onDestroy: () -> Void
    private var isDestroyed = false

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    package init(
        pointer contentTypePointer: OpaquePointer,
        destroy destroyContentType: @escaping (OpaquePointer) -> Void,
        onDestroy handleDestroy: @escaping () -> Void = ignoreSurfaceMetadataProxyDestroy
    ) {
        proxy = RawOwnedProxy(pointer: contentTypePointer, destroy: destroyContentType)
        onDestroy = handleDestroy
    }

    package func setContentType(_ contentType: RawContentType) {
        unsafe swl_wp_content_type_v1_set_content_type(pointer, contentType.rawValue)
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
