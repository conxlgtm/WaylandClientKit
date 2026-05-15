@safe
extension RawOwnedProxy {
    package init(
        adopting proxyPointer: OpaquePointer,
        interface interfaceName: StaticString,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        destroy destroyProxy: @escaping (OpaquePointer) -> Void
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                proxyPointer,
                interface: interfaceName
            )
            self.init(pointer: adoptedPointer, destroy: destroyProxy)
        } catch {
            unsafe destroyProxy(proxyPointer)
            throw error
        }
    }
}
