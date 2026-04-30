package final class RawInputChildProxy {
    package let id: RawInputDeviceID
    package let version: RawVersion

    private let listenerOwner: AnyObject?
    private let cancelListener: (() -> Void)?
    private var proxy: RawOwnedProxy

    package var pointer: OpaquePointer {
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
    ) {
        id = childID
        version = childVersion
        listenerOwner = childListenerOwner
        cancelListener = cancelChildListener
        let adoptedPointer =
            adoptionContext?.adopt(childPointer, interface: interfaceName)
            ?? childPointer
        proxy = RawOwnedProxy(pointer: adoptedPointer, destroy: releaseChildProxy)
    }

    package func destroy() {
        cancelListener?()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
