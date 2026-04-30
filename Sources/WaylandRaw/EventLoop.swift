import CWaylandClientSystem
import Glibc

enum EventLoop {
    package static func fileDescriptor(display: OpaquePointer) -> CInt {
        wl_display_get_fd(display)
    }

    package static func flushForExternalPoll(display: OpaquePointer) throws(RuntimeError) -> Bool {
        while true {
            let result = wl_display_flush(display)
            if result >= 0 {
                return false
            }

            let savedErrno = errno
            if savedErrno == EINTR {
                continue
            }
            if savedErrno == EAGAIN {
                return true
            }
            if savedErrno == EPIPE {
                return false
            }

            throw RuntimeError.fromDisplay(display, fallbackErrno: savedErrno)
        }
    }

    package static func readEvents(display: OpaquePointer) throws(RuntimeError) {
        if wl_display_read_events(display) < 0 {
            throw RuntimeError.fromDisplay(display, fallbackErrno: errno)
        }
    }

    package static func cancelRead(display: OpaquePointer) {
        wl_display_cancel_read(display)
    }
}
