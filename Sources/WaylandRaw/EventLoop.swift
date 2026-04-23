import CWaylandClientSystem
import Glibc

struct EventLoopOperations {
    var prepareRead: (OpaquePointer) -> Int32
    var dispatchPending: (OpaquePointer) -> Int32
    var flush: (OpaquePointer) -> Int32
    var getFileDescriptor: (OpaquePointer) -> Int32
    var pollFileDescriptor: (UnsafeMutablePointer<pollfd>?, nfds_t, Int32) -> Int32
    var readEvents: (OpaquePointer) -> Int32
    var cancelRead: (OpaquePointer) -> Void
    var makeDisplayError: (OpaquePointer, Int32?) -> RuntimeError

    static var live: EventLoopOperations {
        EventLoopOperations(
            prepareRead: wl_display_prepare_read,
            dispatchPending: wl_display_dispatch_pending,
            flush: wl_display_flush,
            getFileDescriptor: wl_display_get_fd,
            pollFileDescriptor: { descriptor, count, timeout in
                Glibc.poll(descriptor, count, timeout)
            },
            readEvents: wl_display_read_events,
            cancelRead: wl_display_cancel_read,
            makeDisplayError: RuntimeError.fromDisplay
        )
    }
}

public enum EventLoop {
    private static let pollFailureEvents = Int16(POLLERR) | Int16(POLLHUP) | Int16(POLLNVAL)

    /// Pump one iteration of the Wayland event loop.
    ///
    /// Follows the canonical prepare-read protocol:
    /// dispatch pending, prepare read, flush, poll, read/cancel, dispatch pending.
    public static func pumpOnce(
        display: OpaquePointer,
        timeoutMilliseconds: Int32
    ) throws {
        try pumpOnce(
            display: display,
            timeoutMilliseconds: timeoutMilliseconds,
            operations: .live
        )
    }

    static func pumpOnce(
        display: OpaquePointer,
        timeoutMilliseconds: Int32,
        operations: EventLoopOperations
    ) throws {
        while operations.prepareRead(display) != 0 {
            let savedErrno = errno
            if savedErrno != EAGAIN {
                throw operations.makeDisplayError(display, savedErrno)
            }

            if operations.dispatchPending(display) < 0 {
                throw operations.makeDisplayError(display, errno)
            }
        }

        let needsWriteWakeup: Bool
        do {
            needsWriteWakeup = try flushDisplay(display: display, operations: operations)
        } catch {
            operations.cancelRead(display)
            throw error
        }

        var events = Int16(POLLIN)
        if needsWriteWakeup {
            events |= Int16(POLLOUT)
        }

        var descriptor = pollfd(
            fd: operations.getFileDescriptor(display),
            events: events,
            revents: 0
        )

        try handlePollResult(
            ready: operations.pollFileDescriptor(&descriptor, 1, timeoutMilliseconds),
            descriptor: descriptor,
            display: display,
            operations: operations
        )

        if operations.dispatchPending(display) < 0 {
            throw operations.makeDisplayError(display, errno)
        }
    }

    /// Block in the event loop until `shouldContinue` returns false.
    public static func run(
        display: OpaquePointer,
        shouldContinue: () -> Bool
    ) throws {
        while shouldContinue() {
            try pumpOnce(display: display, timeoutMilliseconds: -1)
        }
    }

    private static func flushDisplay(
        display: OpaquePointer,
        operations: EventLoopOperations
    ) throws -> Bool {
        while true {
            let result = operations.flush(display)
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

            throw operations.makeDisplayError(display, savedErrno)
        }
    }

    private static func handlePollResult(
        ready: Int32,
        descriptor: pollfd,
        display: OpaquePointer,
        operations: EventLoopOperations
    ) throws {
        guard ready > 0 else {
            operations.cancelRead(display)
            if ready < 0, errno != EINTR {
                throw RuntimeError.pollFailed(errno)
            }
            return
        }

        if descriptor.revents & pollFailureEvents != 0 {
            operations.cancelRead(display)
            throw RuntimeError.pollEventFailed(revents: descriptor.revents)
        }

        if descriptor.revents & Int16(POLLIN) != 0 {
            if operations.readEvents(display) < 0 {
                throw operations.makeDisplayError(display, errno)
            }
        } else {
            operations.cancelRead(display)
        }

        if descriptor.revents & Int16(POLLOUT) != 0 {
            _ = try flushDisplay(display: display, operations: operations)
        }
    }
}
