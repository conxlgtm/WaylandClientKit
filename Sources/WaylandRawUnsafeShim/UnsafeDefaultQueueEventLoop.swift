import CWaylandClientSystem
import Glibc
import WaylandRaw

enum UnsafeDefaultQueueEventLoopError: Error, Equatable, Sendable, CustomStringConvertible {
    case displayError(errno: Int32)
    case pollFailed(Int32)
    case pollEventFailed(revents: Int16)

    var description: String {
        switch self {
        case .displayError(let errno):
            "default-queue Wayland display failed with errno \(errno)"
        case .pollFailed(let errno):
            "default-queue Wayland poll failed with errno \(errno)"
        case .pollEventFailed(let revents):
            "default-queue Wayland poll returned failure events \(revents)"
        }
    }
}

struct EventLoopOperations {
    var prepareRead: (OpaquePointer) -> Int32
    var dispatchPending: (OpaquePointer) -> Int32
    var flush: (OpaquePointer) -> Int32
    var getFileDescriptor: (OpaquePointer) -> Int32
    var pollFileDescriptor: (UnsafeMutablePointer<pollfd>?, nfds_t, Int32) -> Int32
    var readEvents: (OpaquePointer) -> Int32
    var cancelRead: (OpaquePointer) -> Void
    var makeDisplayError: (OpaquePointer, Int32?) -> UnsafeDefaultQueueEventLoopError

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
            makeDisplayError: makeDisplayError
        )
    }

    private static func makeDisplayError(
        display: OpaquePointer,
        fallbackErrno: Int32?
    ) -> UnsafeDefaultQueueEventLoopError {
        let displayErrno = wl_display_get_error(display)
        return .displayError(
            errno: displayErrno != 0 ? displayErrno : fallbackErrno ?? errno)
    }
}

@unsafe
enum UnsafeDefaultQueueEventLoop {
    @available(*, noasync, message: "Only valid for single-threaded default-queue raw clients.")
    static func pumpOnceDefaultQueueUnsafe(
        display: OpaquePointer,
        timeoutMilliseconds: Int32
    ) throws(UnsafeDefaultQueueEventLoopError) {
        try pumpOnce(
            display: display,
            timeoutMilliseconds: timeoutMilliseconds,
            operations: .live
        )
    }

    @available(*, noasync, message: "Only valid for single-threaded default-queue raw clients.")
    static func runDefaultQueueUnsafe(
        display: OpaquePointer,
        shouldContinue: () -> Bool
    ) throws(UnsafeDefaultQueueEventLoopError) {
        while shouldContinue() {
            try pumpOnceDefaultQueueUnsafe(display: display, timeoutMilliseconds: -1)
        }
    }

    static func pumpOnce(
        display: OpaquePointer,
        timeoutMilliseconds: Int32,
        operations: EventLoopOperations,
        wakeFileDescriptor: CInt? = nil,
        drainWakeFileDescriptor: (() -> Void)? = nil
    ) throws(UnsafeDefaultQueueEventLoopError) {
        try QueueEventLoopEngine().step(
            source: DefaultQueueEventLoopSource(display: display, operations: operations),
            timeoutMilliseconds: timeoutMilliseconds,
            wakeFileDescriptor: wakeFileDescriptor,
            drainWakeFileDescriptor: drainWakeFileDescriptor
        )
    }
}

private struct DefaultQueueEventLoopSource: QueueEventLoopSource {
    let display: OpaquePointer
    let operations: EventLoopOperations

    func dispatchPending() throws(UnsafeDefaultQueueEventLoopError) -> Int32 {
        let result = operations.dispatchPending(display)
        guard result >= 0 else {
            throw operations.makeDisplayError(display, errno)
        }

        return result
    }

    func prepareRead() throws(UnsafeDefaultQueueEventLoopError) -> Bool {
        let result = operations.prepareRead(display)
        if result == 0 {
            return true
        }

        let savedErrno = errno
        if savedErrno == EAGAIN {
            return false
        }

        throw operations.makeDisplayError(display, savedErrno)
    }

    func flush() throws(UnsafeDefaultQueueEventLoopError) -> Bool {
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
            if savedErrno == EPIPE {
                return false
            }

            throw operations.makeDisplayError(display, savedErrno)
        }
    }

    func fileDescriptor() throws(UnsafeDefaultQueueEventLoopError) -> CInt {
        operations.getFileDescriptor(display)
    }

    func readEvents() throws(UnsafeDefaultQueueEventLoopError) {
        if operations.readEvents(display) < 0 {
            throw operations.makeDisplayError(display, errno)
        }
    }

    func cancelRead() {
        operations.cancelRead(display)
    }

    func pollFileDescriptors(
        _ descriptors: inout [pollfd],
        timeoutMilliseconds: Int32
    ) throws(UnsafeDefaultQueueEventLoopError) -> Int32 {
        descriptors.withUnsafeMutableBufferPointer { buffer in
            operations.pollFileDescriptor(
                buffer.baseAddress,
                nfds_t(buffer.count),
                timeoutMilliseconds
            )
        }
    }

    func pollFailed(errno: Int32) -> UnsafeDefaultQueueEventLoopError {
        .pollFailed(errno)
    }

    func pollEventFailed(revents: Int16) -> UnsafeDefaultQueueEventLoopError {
        .pollEventFailed(revents: revents)
    }
}
