import CWaylandProtocols

@safe
// SAFETY: RawLinuxDmabuf is display-owned and borrowed only through
// owner-thread graphics preview helpers; callers do not retain or destroy the
// proxy outside DisplayCore.
// swiftlint:disable:next attributes
package final class RawLinuxDmabuf: @unchecked Sendable {
    package static let createParamsMinimumVersion = RawVersion(1)
    package static let feedbackRequestMinimumVersion = RawVersion(4)

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
        proxy = try RawOwnedProxy(
            adopting: linuxDmabufPointer,
            interface: "zwp_linux_dmabuf_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zwp_linux_dmabuf_v1_destroy
        )
        version = linuxDmabufVersion
        proxyAdoption = adoptionContext
    }

    package func requestDefaultFeedback(
        onUpdate handleUpdate: @escaping (RawLinuxDmabufFeedbackSnapshot) -> Void,
        onFailure handleFailure: @escaping (RuntimeError) -> Void
    ) throws -> RawLinuxDmabufFeedback {
        try Self.validateFeedbackRequestVersion(version)
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
        try Self.validateFeedbackRequestVersion(version)
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

    package static func validateFeedbackRequestVersion(
        _ version: RawVersion
    ) throws(RuntimeError) {
        guard version >= feedbackRequestMinimumVersion else {
            throw RuntimeError.unsupportedProtocolVersion(
                interface: "zwp_linux_dmabuf_v1 feedback",
                minimum: feedbackRequestMinimumVersion,
                actual: version
            )
        }
    }

    package func createBufferParams(
        onEvent handleEvent: @escaping (RawLinuxDmabufBufferParamsEvent) -> Void,
        onFailure handleFailure: @escaping (RuntimeError) -> Void
    ) throws -> RawLinuxDmabufBufferParams {
        try Self.validateCreateParamsVersion(version)
        guard
            let params = unsafe swl_zwp_linux_dmabuf_v1_create_params(pointer)
        else {
            throw RuntimeError.bindFailed("zwp_linux_buffer_params_v1")
        }

        return try RawLinuxDmabufBufferParams(
            pointer: params,
            proxyAdoption: proxyAdoption,
            onEvent: handleEvent,
            onFailure: handleFailure
        )
    }

    package static func validateCreateParamsVersion(
        _ version: RawVersion
    ) throws(RuntimeError) {
        guard version >= createParamsMinimumVersion else {
            throw RuntimeError.unsupportedProtocolVersion(
                interface: "zwp_linux_dmabuf_v1 create_params",
                minimum: createParamsMinimumVersion,
                actual: version
            )
        }
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
