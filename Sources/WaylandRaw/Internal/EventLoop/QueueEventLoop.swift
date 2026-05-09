import CWaylandProtocols
import Glibc

@safe
enum QueueEventLoop {
    package static func dispatchPending(
        display: OpaquePointer,
        eventQueue: OpaquePointer
    ) throws(RuntimeError) -> Int32 {
        let result = unsafe swl_display_dispatch_event_queue_pending(display, eventQueue)
        guard result >= 0 else {
            throw RuntimeError.fromDisplay(
                display,
                fallbackErrno: errno,
                operation: .displayDispatchPending
            )
        }

        return result
    }

    package static func prepareRead(
        display: OpaquePointer,
        eventQueue: OpaquePointer
    ) throws(RuntimeError) -> Bool {
        let result = unsafe swl_display_prepare_read_event_queue(display, eventQueue)
        if result == 0 {
            return true
        }

        let savedErrno = errno
        if savedErrno == EAGAIN {
            return false
        }

        throw RuntimeError.fromDisplay(
            display,
            fallbackErrno: savedErrno,
            operation: .displayPrepareRead
        )
    }

    package static func pumpOnce(
        display: OpaquePointer,
        eventQueue: OpaquePointer,
        timeoutMilliseconds: Int32
    ) throws(RuntimeError) {
        try QueueEventLoopEngine().step(
            source: RawQueueEventLoopSource(display: display, eventQueue: eventQueue),
            timeoutMilliseconds: timeoutMilliseconds
        )
    }

    package static func pumpOnce(
        display: OpaquePointer,
        eventQueue: OpaquePointer,
        timeoutMilliseconds: Int32,
        wakeFileDescriptor: CInt,
        drainWakeFileDescriptor: @escaping () -> Void
    ) throws(RuntimeError) {
        try QueueEventLoopEngine().step(
            source: RawQueueEventLoopSource(display: display, eventQueue: eventQueue),
            timeoutMilliseconds: timeoutMilliseconds,
            wakeFileDescriptor: wakeFileDescriptor,
            drainWakeFileDescriptor: drainWakeFileDescriptor
        )
    }

    package static func run(
        display: OpaquePointer,
        eventQueue: OpaquePointer,
        shouldContinue: () -> Bool
    ) throws(RuntimeError) {
        while shouldContinue() {
            try unsafe pumpOnce(
                display: display,
                eventQueue: eventQueue,
                timeoutMilliseconds: -1
            )
        }
    }
}

@safe
private struct RawQueueEventLoopSource: QueueEventLoopSource {
    @safe let display: OpaquePointer
    @safe let eventQueue: OpaquePointer

    @safe
    init(display: OpaquePointer, eventQueue: OpaquePointer) {
        unsafe self.display = display
        unsafe self.eventQueue = eventQueue
    }

    func dispatchPending() throws(RuntimeError) -> Int32 {
        try unsafe QueueEventLoop.dispatchPending(display: display, eventQueue: eventQueue)
    }

    func prepareRead() throws(RuntimeError) -> Bool {
        try unsafe QueueEventLoop.prepareRead(display: display, eventQueue: eventQueue)
    }

    func flush() throws(RuntimeError) -> Bool {
        try unsafe EventLoop.flushForExternalPoll(display: display)
    }

    func fileDescriptor() throws(RuntimeError) -> CInt {
        unsafe EventLoop.fileDescriptor(display: display)
    }

    func readEvents() throws(RuntimeError) {
        try unsafe EventLoop.readEvents(display: display)
    }

    func cancelRead() {
        unsafe EventLoop.cancelRead(display: display)
    }

    func pollFileDescriptors(
        _ descriptors: inout [pollfd],
        timeoutMilliseconds: Int32
    ) throws(RuntimeError) -> Int32 {
        unsafe descriptors.withUnsafeMutableBufferPointer { buffer in
            unsafe Glibc.poll(buffer.baseAddress, nfds_t(buffer.count), timeoutMilliseconds)
        }
    }

    func eventLoopFailed(_ error: RawEventLoopError) -> RuntimeError {
        .eventLoop(error)
    }
}
