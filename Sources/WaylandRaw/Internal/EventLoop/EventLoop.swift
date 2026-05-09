import CWaylandClientSystem
import Glibc

@safe
enum EventLoop {
    package static func fileDescriptor(display: OpaquePointer) -> CInt {
        unsafe wl_display_get_fd(display)
    }

    package static func flushForExternalPoll(display: OpaquePointer) throws(RuntimeError) -> Bool {
        while true {
            let result = unsafe wl_display_flush(display)
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

            throw RuntimeError.fromDisplay(
                display,
                fallbackErrno: savedErrno,
                operation: .displayFlush
            )
        }
    }

    package static func readEvents(display: OpaquePointer) throws(RuntimeError) {
        if unsafe wl_display_read_events(display) < 0 {
            throw RuntimeError.fromDisplay(
                display,
                fallbackErrno: errno,
                operation: .displayReadEvents
            )
        }
    }

    package static func cancelRead(display: OpaquePointer) {
        unsafe wl_display_cancel_read(display)
    }
}
