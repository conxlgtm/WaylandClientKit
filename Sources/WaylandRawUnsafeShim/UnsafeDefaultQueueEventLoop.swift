import CWaylandClientSystem
import Glibc
import WaylandRaw

enum UnsafeDefaultQueueEventLoopError: Error, Equatable, Sendable, CustomStringConvertible {
    case displayError(RawSystemError)
    case displayErrnoUnavailable(operation: RawSystemOperation)
    case eventLoop(RawEventLoopError)

    var description: String {
        switch self {
        case .displayError(let error):
            "default-queue Wayland display failed: \(error.description)"
        case .displayErrnoUnavailable(let operation):
            "default-queue Wayland display failed during \(operation.description) without errno"
        case .eventLoop(let error):
            "default-queue Wayland event loop failed: \(error.description)"
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
    var makeDisplayError:
        (OpaquePointer, Int32?, RawSystemOperation) -> UnsafeDefaultQueueEventLoopError

    static var live: EventLoopOperations {
        EventLoopOperations(
            prepareRead: unsafe wl_display_prepare_read,
            dispatchPending: unsafe wl_display_dispatch_pending,
            flush: unsafe wl_display_flush,
            getFileDescriptor: unsafe wl_display_get_fd,
            pollFileDescriptor: { descriptor, count, timeout in
                unsafe Glibc.poll(descriptor, count, timeout)
            },
            readEvents: unsafe wl_display_read_events,
            cancelRead: unsafe wl_display_cancel_read,
            makeDisplayError: makeDisplayError
        )
    }

    private static func makeDisplayError(
        display: OpaquePointer,
        fallbackErrno: Int32?,
        operation: RawSystemOperation
    ) -> UnsafeDefaultQueueEventLoopError {
        let displayErrno = unsafe wl_display_get_error(display)
        let resolvedErrno = displayErrno != 0 ? displayErrno : fallbackErrno ?? errno
        guard resolvedErrno != 0 else {
            return .displayErrnoUnavailable(operation: operation)
        }

        return .displayError(
            RawSystemError(uncheckedErrno: resolvedErrno, operation: operation)
        )
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
            throw operations.makeDisplayError(display, errno, .displayDispatchPending)
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

        throw operations.makeDisplayError(display, savedErrno, .displayPrepareRead)
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

            throw operations.makeDisplayError(display, savedErrno, .displayFlush)
        }
    }

    func fileDescriptor() throws(UnsafeDefaultQueueEventLoopError) -> CInt {
        operations.getFileDescriptor(display)
    }

    func readEvents() throws(UnsafeDefaultQueueEventLoopError) {
        if operations.readEvents(display) < 0 {
            throw operations.makeDisplayError(display, errno, .displayReadEvents)
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

    func eventLoopFailed(_ error: RawEventLoopError) -> UnsafeDefaultQueueEventLoopError {
        .eventLoop(error)
    }
}
