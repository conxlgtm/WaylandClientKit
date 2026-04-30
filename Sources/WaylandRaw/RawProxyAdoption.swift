import CWaylandProtocols

package struct RawProxyAdoptionContext {
    private let eventQueue: RawEventQueue
    package let invariantFailureSink: RawInvariantFailureSink

    package init(
        eventQueue ownerQueue: RawEventQueue,
        invariantFailureSink failureSink: RawInvariantFailureSink = .init()
    ) {
        eventQueue = ownerQueue
        invariantFailureSink = failureSink
    }

    package func adopt(
        _ proxy: OpaquePointer,
        interface interfaceName: StaticString
    ) -> OpaquePointer {
        eventQueue.assertOwns(
            proxy: proxy,
            interface: interfaceName,
            invariantFailureSink: invariantFailureSink
        )
        return proxy
    }
}

extension RawEventQueue {
    package func assertOwns(
        proxy: OpaquePointer,
        interface interfaceName: StaticString,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        #if DEBUG
            let rawProxy = unsafe UnsafeMutableRawPointer(proxy)
            guard
                let actualQueue = unsafe swl_proxy_get_queue_raw(rawProxy)
            else { return }
            let expectedQueue = unsafe opaquePointer
            if actualQueue != expectedQueue {
                failureSink?.reportFatalRawInvariantFailure(
                    .proxyOnWrongQueue(interface: "\(interfaceName)")
                )
            }
            precondition(
                actualQueue == expectedQueue,
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
