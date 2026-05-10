import CWaylandProtocols
import Glibc

@safe
package final class RawViewporter {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer viewporterPointer: OpaquePointer,
        version viewporterVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                viewporterPointer,
                interface: "wp_viewporter"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_wp_viewporter_destroy
            )
        } catch {
            unsafe swl_wp_viewporter_destroy(viewporterPointer)
            throw error
        }
        version = viewporterVersion
        proxyAdoption = adoptionContext
    }

    package func getViewport(for surface: RawSurface) throws -> RawViewport {
        guard
            let viewport = unsafe swl_wp_viewporter_get_viewport(pointer, surface.pointer)
        else {
            throw RuntimeError.bindFailed("wp_viewport")
        }

        return try .init(pointer: viewport, version: version, proxyAdoption: proxyAdoption)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawViewport {
    package let version: RawVersion

    private var proxy: RawOwnedProxy

    @safe var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer viewportPointer: OpaquePointer,
        version viewportVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                viewportPointer,
                interface: "wp_viewport"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_wp_viewport_destroy
            )
        } catch {
            unsafe swl_wp_viewport_destroy(viewportPointer)
            throw error
        }
        version = viewportVersion
    }

    package func setDestination(width: Int32, height: Int32) {
        unsafe swl_wp_viewport_set_destination(pointer, width, height)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawFractionalScaleManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                managerPointer,
                interface: "wp_fractional_scale_manager_v1"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_wp_fractional_scale_manager_v1_destroy
            )
        } catch {
            unsafe swl_wp_fractional_scale_manager_v1_destroy(managerPointer)
            throw error
        }
        version = managerVersion
        proxyAdoption = adoptionContext
    }

    package func getFractionalScale(for surface: RawSurface) throws -> RawFractionalScale {
        guard
            let fractionalScale = unsafe swl_wp_fractional_scale_manager_v1_get_fractional_scale(
                pointer,
                surface.pointer
            )
        else {
            throw RuntimeError.bindFailed("wp_fractional_scale_v1")
        }

        return try .init(
            pointer: fractionalScale,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawFractionalScale {
    package let version: RawVersion

    private var proxy: RawOwnedProxy

    @safe var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer fractionalScalePointer: OpaquePointer,
        version fractionalScaleVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                fractionalScalePointer,
                interface: "wp_fractional_scale_v1"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_wp_fractional_scale_v1_destroy
            )
        } catch {
            unsafe swl_wp_fractional_scale_v1_destroy(fractionalScalePointer)
            throw error
        }
        version = fractionalScaleVersion
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

private enum ScaleListenerInstallState {
    case idle
    case installed
}

private typealias SurfaceScaleListenerCallbacks = swl_surface_listener_callbacks

@safe
package final class RawSurfaceScaleOwner {
    private let onPreferredBufferScale: (Int32) -> Void
    private let onOutputEnter: (RawOutputPointerIdentity) -> Void
    private let onOutputLeave: (RawOutputPointerIdentity) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = ScaleListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_surface_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<SurfaceScaleListenerCallbacks> {
        listenerStorage.callbacks
    }

    package init(
        onPreferredBufferScale handler: @escaping (Int32) -> Void,
        onOutputEnter handleOutputEnter: @escaping (RawOutputPointerIdentity) -> Void = { _ in () },
        onOutputLeave handleOutputLeave: @escaping (RawOutputPointerIdentity) -> Void = { _ in () },
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        onPreferredBufferScale = handler
        onOutputEnter = handleOutputEnter
        onOutputLeave = handleOutputLeave
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.enter = { data, _, output in
            guard let output = unsafe output else { return }
            RawSurfaceScaleOwner.withOwner(
                data,
                message: "wl_surface enter fired without Swift state"
            ) { owner in
                owner.onOutputEnter(RawOutputPointerIdentity(output))
            }
        }
        unsafe callbacks.pointee.leave = { data, _, output in
            guard let output = unsafe output else { return }
            RawSurfaceScaleOwner.withOwner(
                data,
                message: "wl_surface leave fired without Swift state"
            ) { owner in
                owner.onOutputLeave(RawOutputPointerIdentity(output))
            }
        }
        unsafe callbacks.pointee.preferred_buffer_scale = { data, _, factor in
            RawSurfaceScaleOwner.withOwner(
                data,
                message: "wl_surface preferred_buffer_scale fired without Swift state"
            ) { owner in
                owner.onPreferredBufferScale(factor)
            }
        }
    }

    package func install(on surface: RawSurface) throws {
        guard installState == .idle else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("wl_surface")
            )
        }

        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_surface_add_listener(surface.pointer, callbacks)

        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("wl_surface")
            )
        }

        installState = .installed
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawSurfaceScaleOwner) -> Void
    ) {
        CListenerStorage<
            RawSurfaceScaleOwner,
            SurfaceScaleListenerCallbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}

private typealias FractionalScaleListenerCallbacks =
    swl_wp_fractional_scale_v1_listener_callbacks

@safe
package final class RawFractionalScaleOwner {
    private let onPreferredScale: (UInt32) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = ScaleListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_wp_fractional_scale_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<FractionalScaleListenerCallbacks> {
        listenerStorage.callbacks
    }

    package init(
        onPreferredScale handler: @escaping (UInt32) -> Void,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        onPreferredScale = handler
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.preferred_scale = { data, _, scale in
            RawFractionalScaleOwner.withOwner(
                data,
                message: "wp_fractional_scale_v1 preferred_scale fired without Swift state"
            ) { owner in
                owner.onPreferredScale(scale)
            }
        }
    }

    package func install(on fractionalScale: RawFractionalScale) throws {
        guard installState == .idle else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("wp_fractional_scale_v1")
            )
        }

        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_wp_fractional_scale_v1_add_listener(
            fractionalScale.pointer,
            callbacks
        )

        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("wp_fractional_scale_v1")
            )
        }

        installState = .installed
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawFractionalScaleOwner) -> Void
    ) {
        CListenerStorage<
            RawFractionalScaleOwner,
            FractionalScaleListenerCallbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}
