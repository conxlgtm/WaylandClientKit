import CWaylandProtocols

@safe
package final class RawEventQueue: CustomStringConvertible {
    @safe package let opaquePointer: OpaquePointer
    private var didDestroy = false

    @safe
    package init(opaquePointer eventQueuePointer: OpaquePointer) {
        unsafe opaquePointer = eventQueuePointer
    }

    @safe
    func destroy() {
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
