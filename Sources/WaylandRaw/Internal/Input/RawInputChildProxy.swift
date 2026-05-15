@safe
package final class RawInputChildProxy {
    package let id: RawInputDeviceID
    package let version: RawVersion

    private let listenerOwner: AnyObject?
    private let cancelListener: (() -> Void)?
    private var proxy: RawOwnedProxy

    @safe package var pointer: OpaquePointer {
        proxy.pointer
    }

    package init(
        id childID: RawInputDeviceID,
        pointer childPointer: OpaquePointer,
        version childVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext?,
        interface interfaceName: StaticString,
        listenerOwner childListenerOwner: AnyObject?,
        cancelListener cancelChildListener: (() -> Void)? = nil,
        release releaseChildProxy: @escaping (OpaquePointer) -> Void
    ) throws(RuntimeError) {
        id = childID
        version = childVersion
        listenerOwner = childListenerOwner
        cancelListener = cancelChildListener
        if let adoptionContext {
            do {
                proxy = try RawOwnedProxy(
                    adopting: childPointer,
                    interface: interfaceName,
                    proxyAdoption: adoptionContext,
                    destroy: releaseChildProxy
                )
            } catch {
                cancelChildListener?()
                throw error
            }
        } else {
            proxy = RawOwnedProxy(pointer: childPointer, destroy: releaseChildProxy)
        }
    }

    package func destroy() {
        cancelListener?()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
