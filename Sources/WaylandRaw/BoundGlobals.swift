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
    public let seat: RawSeat?

    private var isDestroyed = false

    init(
        compositor boundCompositor: RawCompositor,
        sharedMemory boundSharedMemory: RawSharedMemory,
        xdgWMBase boundXDGWMBase: RawXDGWMBase,
        seat boundSeat: RawSeat?
    ) {
        compositor = boundCompositor
        sharedMemory = boundSharedMemory
        xdgWMBase = boundXDGWMBase
        seat = boundSeat
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        seat?.destroy()
        xdgWMBase.destroy()
        sharedMemory.destroy()
        compositor.destroy()
    }

    deinit {
        destroy()
    }
}

public final class RawSeat {
    let pointer: OpaquePointer
    public let version: RawVersion

    private var isDestroyed = false

    init(pointer seatPointer: OpaquePointer, version seatVersion: RawVersion) {
        pointer = seatPointer
        version = seatVersion
    }

    func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        if version >= 5 {
            swl_seat_release(pointer)
        } else {
            swl_seat_destroy(pointer)
        }
    }

    deinit {
        destroy()
    }
}
