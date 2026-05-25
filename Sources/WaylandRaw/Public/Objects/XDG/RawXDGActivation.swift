import CWaylandProtocols

@safe
package final class RawXDGActivation {
    package let version: RawVersion

    private var proxy: RawOwnedProxy

    @safe
    init(
        pointer activationPointer: OpaquePointer,
        version activationVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = activationVersion
        proxy = try RawOwnedProxy(
            adopting: activationPointer,
            interface: "xdg_activation_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_xdg_activation_v1_destroy
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
