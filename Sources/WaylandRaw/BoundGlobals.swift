import CWaylandClientSystem
import CWaylandProtocols

package enum SupportedVersions {
    package static let wlCompositor: RawVersion = 6
    package static let wlShm: RawVersion = 1
    package static let xdgWmBase: RawVersion = 7
    package static let wlSeat: RawVersion = 10
}

package final class BoundGlobals {
    package let compositor: RawCompositor
    package let sharedMemory: RawSharedMemory
    package let xdgWMBase: RawXDGWMBase
    package let seatRegistry: SeatRegistry

    private var isDestroyed = false

    init(
        compositor boundCompositor: RawCompositor,
        sharedMemory boundSharedMemory: RawSharedMemory,
        xdgWMBase boundXDGWMBase: RawXDGWMBase,
        seatRegistry boundSeatRegistry: SeatRegistry
    ) {
        compositor = boundCompositor
        sharedMemory = boundSharedMemory
        xdgWMBase = boundXDGWMBase
        seatRegistry = boundSeatRegistry
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        seatRegistry.destroy()
        xdgWMBase.destroy()
        sharedMemory.destroy()
        compositor.destroy()
    }

    deinit {
        destroy()
    }
}
