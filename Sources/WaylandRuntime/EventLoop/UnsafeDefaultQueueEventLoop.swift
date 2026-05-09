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

@safe
struct EventLoopOperations {
    @safe var prepareRead: (OpaquePointer) -> Int32
    @safe var dispatchPending: (OpaquePointer) -> Int32
    @safe var flush: (OpaquePointer) -> Int32
    @safe var getFileDescriptor: (OpaquePointer) -> Int32
    @safe var pollFileDescriptor: (UnsafeMutablePointer<pollfd>?, nfds_t, Int32) -> Int32
    @safe var readEvents: (OpaquePointer) -> Int32
    @safe var cancelRead: (OpaquePointer) -> Void
    @safe var makeDisplayError:
        (OpaquePointer, Int32?, RawSystemOperation) -> UnsafeDefaultQueueEventLoopError

    static var live: EventLoopOperations {
        unsafe EventLoopOperations(
            prepareRead: unsafe wl_display_prepare_read,
            dispatchPending: unsafe wl_display_dispatch_pending,
            flush: unsafe wl_display_flush,
            getFileDescriptor: unsafe wl_display_get_fd,
            pollFileDescriptor: { descriptor, count, timeout in
                unsafe Glibc.poll(descriptor, count, timeout)
            },
            readEvents: unsafe wl_display_read_events,
            cancelRead: unsafe wl_display_cancel_read,
            makeDisplayError: unsafe makeDisplayError
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
        try unsafe pumpOnce(
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
            try unsafe pumpOnceDefaultQueueUnsafe(display: display, timeoutMilliseconds: -1)
        }
    }

    static func pumpOnce(
        display: OpaquePointer,
        timeoutMilliseconds: Int32,
        operations: EventLoopOperations,
        wakeFileDescriptor: CInt? = nil,
        drainWakeFileDescriptor: (() -> Void)? = nil
    ) throws(UnsafeDefaultQueueEventLoopError) {
        try unsafe QueueEventLoopEngine().step(
            source: DefaultQueueEventLoopSource(display: display, operations: operations),
            timeoutMilliseconds: timeoutMilliseconds,
            wakeFileDescriptor: wakeFileDescriptor,
            drainWakeFileDescriptor: drainWakeFileDescriptor
        )
    }
}

@safe
private struct DefaultQueueEventLoopSource: QueueEventLoopSource {
    @safe let display: OpaquePointer
    let operations: EventLoopOperations

    func dispatchPending() throws(UnsafeDefaultQueueEventLoopError) -> Int32 {
        let result = unsafe operations.dispatchPending(display)
        guard result >= 0 else {
            throw unsafe operations.makeDisplayError(display, errno, .displayDispatchPending)
        }

        return result
    }

    func prepareRead() throws(UnsafeDefaultQueueEventLoopError) -> Bool {
        let result = unsafe operations.prepareRead(display)
        if result == 0 {
            return true
        }

        let savedErrno = errno
        if savedErrno == EAGAIN {
            return false
        }

        throw unsafe operations.makeDisplayError(display, savedErrno, .displayPrepareRead)
    }

    func flush() throws(UnsafeDefaultQueueEventLoopError) -> Bool {
        while true {
            let result = unsafe operations.flush(display)
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

            throw unsafe operations.makeDisplayError(display, savedErrno, .displayFlush)
        }
    }

    func fileDescriptor() throws(UnsafeDefaultQueueEventLoopError) -> CInt {
        unsafe operations.getFileDescriptor(display)
    }

    func readEvents() throws(UnsafeDefaultQueueEventLoopError) {
        if unsafe operations.readEvents(display) < 0 {
            throw unsafe operations.makeDisplayError(display, errno, .displayReadEvents)
        }
    }

    func cancelRead() {
        unsafe operations.cancelRead(display)
    }

    func pollFileDescriptors(
        _ descriptors: inout [pollfd],
        timeoutMilliseconds: Int32
    ) throws(UnsafeDefaultQueueEventLoopError) -> Int32 {
        unsafe descriptors.withUnsafeMutableBufferPointer { buffer in
            unsafe operations.pollFileDescriptor(
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
