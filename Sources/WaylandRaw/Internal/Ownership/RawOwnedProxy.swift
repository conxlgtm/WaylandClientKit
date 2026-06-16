@safe
package struct RawOwnedProxy: ~Copyable {
    @safe package let pointer: OpaquePointer
    private let destroyProxy: (OpaquePointer) -> Void
    private var isDestroyed = false

    @safe
    package init(
        pointer proxyPointer: OpaquePointer,
        destroy destroyProxyFunction: @escaping (OpaquePointer) -> Void
    ) {
        unsafe pointer = proxyPointer
        unsafe destroyProxy = destroyProxyFunction
    }

    @safe
    package mutating func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        unsafe destroyProxy(pointer)
    }

    package mutating func abandon() {
        isDestroyed = true
    }

    deinit {
        if !isDestroyed {
            unsafe destroyProxy(pointer)
        }
    }
}
