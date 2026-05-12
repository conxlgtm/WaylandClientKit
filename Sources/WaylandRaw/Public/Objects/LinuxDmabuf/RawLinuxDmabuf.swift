import CWaylandProtocols

@safe
package final class RawLinuxDmabuf {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer linuxDmabufPointer: OpaquePointer,
        version linuxDmabufVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                linuxDmabufPointer,
                interface: "zwp_linux_dmabuf_v1"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_zwp_linux_dmabuf_v1_destroy
            )
        } catch {
            unsafe swl_zwp_linux_dmabuf_v1_destroy(linuxDmabufPointer)
            throw error
        }
        version = linuxDmabufVersion
        proxyAdoption = adoptionContext
    }

    package func requestDefaultFeedback(
        onUpdate handleUpdate: @escaping (RawLinuxDmabufFeedbackSnapshot) -> Void,
        onFailure handleFailure: @escaping (RuntimeError) -> Void
    ) throws -> RawLinuxDmabufFeedback {
        guard
            let feedback = unsafe swl_zwp_linux_dmabuf_v1_get_default_feedback(pointer)
        else {
            throw RuntimeError.bindFailed("zwp_linux_dmabuf_feedback_v1")
        }

        return try RawLinuxDmabufFeedback(
            pointer: feedback,
            scope: .defaultFeedback,
            proxyAdoption: proxyAdoption,
            onUpdate: handleUpdate,
            onFailure: handleFailure
        )
    }

    package func requestSurfaceFeedback(
        for surface: RawSurface,
        onUpdate handleUpdate: @escaping (RawLinuxDmabufFeedbackSnapshot) -> Void,
        onFailure handleFailure: @escaping (RuntimeError) -> Void
    ) throws -> RawLinuxDmabufFeedback {
        guard
            let feedback = unsafe swl_zwp_linux_dmabuf_v1_get_surface_feedback(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("zwp_linux_dmabuf_feedback_v1")
        }

        return try RawLinuxDmabufFeedback(
            pointer: feedback,
            scope: .surface(surfaceID: surface.objectID),
            proxyAdoption: proxyAdoption,
            onUpdate: handleUpdate,
            onFailure: handleFailure
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
