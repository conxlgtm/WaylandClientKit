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
    ) throws(RuntimeError) -> OpaquePointer {
        try eventQueue.assertOwns(
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
    ) throws(RuntimeError) {
        let rawProxy = unsafe UnsafeMutableRawPointer(proxy)
        guard
            let actualQueue = unsafe swl_proxy_get_queue_raw(rawProxy)
        else {
            // Older libwayland headers do not expose runtime queue inspection;
            // in that case queue ownership is enforced by the wrapper creation path.
            return
        }

        let expectedQueue = unsafe opaquePointer
        if actualQueue != expectedQueue {
            try Self.reportQueueMismatch(
                interface: interfaceName,
                invariantFailureSink: failureSink
            )
        }
    }

    package func assertedProxy(
        _ proxy: OpaquePointer,
        interface interfaceName: StaticString,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) throws(RuntimeError) -> OpaquePointer {
        try assertOwns(
            proxy: proxy,
            interface: interfaceName,
            invariantFailureSink: failureSink
        )
        return proxy
    }

    package static func reportQueueMismatch(
        interface interfaceName: StaticString,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) throws(RuntimeError) {
        let interface = "\(interfaceName)"
        let failure = RawInvariantFailure.proxyOnWrongQueue(interface: interface)
        if let failureSink {
            failureSink.reportFatalRawInvariantFailure(failure)
        } else {
            RawInvariantFailureSink.trapForUnroutedFatalRawInvariantFailure(failure)
        }

        throw RuntimeError.proxyQueueMismatch(interface)
    }
}
