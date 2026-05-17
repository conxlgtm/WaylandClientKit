import CWaylandProtocols

@safe
package final class RawEventQueue: CustomStringConvertible {
    @safe package let opaquePointer: OpaquePointer
    private let destroysOnDeinit: Bool
    private var didDestroy = false

    @safe
    package init(opaquePointer eventQueuePointer: OpaquePointer) {
        self.destroysOnDeinit = true
        unsafe opaquePointer = eventQueuePointer
    }

    private init(
        opaquePointer eventQueuePointer: OpaquePointer,
        destroysOnDeinit shouldDestroyOnDeinit: Bool
    ) {
        destroysOnDeinit = shouldDestroyOnDeinit
        unsafe opaquePointer = eventQueuePointer
    }

    @safe
    func destroy() {
        guard destroysOnDeinit else { return }
        guard !didDestroy else { return }
        didDestroy = true
        unsafe swl_event_queue_destroy(opaquePointer)
    }

    deinit {
        destroy()
    }

    @safe package var description: String {
        let address = UInt(bitPattern: opaquePointer)
        return "wl_event_queue(0x\(String(address, radix: 16)))"
    }
}

extension RawEventQueue {
    @safe
    package static func testingQueueWithoutDestroy(
        opaquePointer eventQueuePointer: OpaquePointer
    ) -> RawEventQueue {
        unsafe RawEventQueue(
            opaquePointer: eventQueuePointer,
            destroysOnDeinit: false
        )
    }
}
