import CWaylandClientSystem
import CWaylandProtocols

public enum SupportedVersions {
    public static let wlCompositor: RawVersion = 6
    public static let wlShm: RawVersion = 1
    public static let xdgWmBase: RawVersion = 7
    public static let wlSeat: RawVersion = 10
}

public final class BoundGlobals {
    public let compositor: RawCompositor
    public let sharedMemory: RawSharedMemory
    public let xdgWMBase: RawXDGWMBase
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
