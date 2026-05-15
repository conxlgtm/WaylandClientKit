@safe
extension RawOwnedProxy {
    package init(
        adopting proxyPointer: OpaquePointer,
        interface interfaceName: StaticString,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        destroy destroyProxy: @escaping (OpaquePointer) -> Void
    ) throws(RuntimeError) {
        let adoptedPointer = try unsafe adoptionContext.adoptOrDestroy(
            proxyPointer,
            interface: interfaceName,
            destroy: destroyProxy
        )
        self.init(pointer: adoptedPointer, destroy: destroyProxy)
    }
}
