import CWaylandProtocols

package struct RawProxyAdoptionContext {
    private let eventQueue: RawEventQueue

    package init(eventQueue ownerQueue: RawEventQueue) {
        eventQueue = ownerQueue
    }

    package func adopt(
        _ proxy: OpaquePointer,
        interface interfaceName: StaticString
    ) -> OpaquePointer {
        eventQueue.assertOwns(proxy: proxy, interface: interfaceName)
        return proxy
    }
}

extension RawEventQueue {
    package func assertOwns(
        proxy: OpaquePointer,
        interface interfaceName: StaticString
    ) {
        #if DEBUG
            let actualQueue = swl_proxy_get_queue_raw(UnsafeMutableRawPointer(proxy))
            precondition(
                actualQueue == opaquePointer,
                "\(interfaceName) proxy is not assigned to the display owner event queue"
            )
        #endif
    }

    package func assertedProxy(
        _ proxy: OpaquePointer,
        interface interfaceName: StaticString
    ) -> OpaquePointer {
        assertOwns(proxy: proxy, interface: interfaceName)
        return proxy
    }
}
