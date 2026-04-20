import CWaylandClientSystem
import CWaylandProtocols

public enum SupportedVersions {
    public static let wlCompositor: RawVersion = 6
    public static let wlShm: RawVersion = 1
    public static let xdgWmBase: RawVersion = 7
    public static let wlSeat: RawVersion = 9
}

public struct BoundGlobals {
    public let compositor: OpaquePointer
    public let compositorVersion: RawVersion
    public let shm: OpaquePointer
    public let shmVersion: RawVersion
    public let xdgWmBase: OpaquePointer
    public let xdgWmBaseVersion: RawVersion
    public let seat: OpaquePointer?
    public let seatVersion: RawVersion?
}

extension BoundGlobals {
    func destroy() {
        if let seat {
            if let seatVersion, seatVersion >= 5 {
                swl_seat_release(seat)
            } else {
                swl_seat_destroy(seat)
            }
        }

        swl_xdg_wm_base_destroy(self.xdgWmBase)
        swl_shm_destroy(self.shm)
        swl_compositor_destroy(self.compositor)
    }
}
