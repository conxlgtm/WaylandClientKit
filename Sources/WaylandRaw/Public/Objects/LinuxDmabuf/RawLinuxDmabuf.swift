import CWaylandProtocols

@safe
package final class RawLinuxDmabuf {
    package let version: RawVersion

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
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
