package struct RawOwnedProxy: ~Copyable {
    package let pointer: OpaquePointer
    private let destroyProxy: (OpaquePointer) -> Void
    private var isDestroyed = false

    package init(
        pointer proxyPointer: OpaquePointer,
        destroy destroyProxyFunction: @escaping (OpaquePointer) -> Void
    ) {
        pointer = proxyPointer
        destroyProxy = destroyProxyFunction
    }

    package mutating func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        destroyProxy(pointer)
    }

    deinit {
        if !isDestroyed {
            destroyProxy(pointer)
        }
    }
}
