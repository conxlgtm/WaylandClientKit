import CWaylandProtocols

package final class RawEventQueue: CustomStringConvertible {
    package let opaquePointer: OpaquePointer
    private var didDestroy = false

    package init(opaquePointer eventQueuePointer: OpaquePointer) {
        opaquePointer = eventQueuePointer
    }

    func destroy() {
        guard !didDestroy else { return }
        didDestroy = true
        swl_event_queue_destroy(opaquePointer)
    }

    deinit {
        destroy()
    }

    package var description: String {
        "wl_event_queue(\(opaquePointer))"
    }
}
