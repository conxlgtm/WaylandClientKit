import CWaylandProtocols
import Glibc

enum QueueEventLoop {
    package static func dispatchPending(
        display: OpaquePointer,
        eventQueue: OpaquePointer
    ) throws(RuntimeError) -> Int32 {
        let result = swl_display_dispatch_event_queue_pending(display, eventQueue)
        guard result >= 0 else {
            throw RuntimeError.fromDisplay(display, fallbackErrno: errno)
        }

        return result
    }

    package static func prepareRead(
        display: OpaquePointer,
        eventQueue: OpaquePointer
    ) throws(RuntimeError) -> Bool {
        let result = swl_display_prepare_read_event_queue(display, eventQueue)
        if result == 0 {
            return true
        }

        let savedErrno = errno
        if savedErrno == EAGAIN {
            return false
        }

        throw RuntimeError.fromDisplay(display, fallbackErrno: savedErrno)
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
            try pumpOnce(
                display: display,
                eventQueue: eventQueue,
                timeoutMilliseconds: -1
            )
        }
    }
}

private struct RawQueueEventLoopSource: QueueEventLoopSource {
    let display: OpaquePointer
    let eventQueue: OpaquePointer

    func dispatchPending() throws(RuntimeError) -> Int32 {
        try QueueEventLoop.dispatchPending(display: display, eventQueue: eventQueue)
    }

    func prepareRead() throws(RuntimeError) -> Bool {
        try QueueEventLoop.prepareRead(display: display, eventQueue: eventQueue)
    }

    func flush() throws(RuntimeError) -> Bool {
        try EventLoop.flushForExternalPoll(display: display)
    }

    func fileDescriptor() throws(RuntimeError) -> CInt {
        EventLoop.fileDescriptor(display: display)
    }

    func readEvents() throws(RuntimeError) {
        try EventLoop.readEvents(display: display)
    }

    func cancelRead() {
        EventLoop.cancelRead(display: display)
    }

    func pollFileDescriptors(
        _ descriptors: inout [pollfd],
        timeoutMilliseconds: Int32
    ) throws(RuntimeError) -> Int32 {
        descriptors.withUnsafeMutableBufferPointer { buffer in
            Glibc.poll(buffer.baseAddress, nfds_t(buffer.count), timeoutMilliseconds)
        }
    }

    func pollFailed(errno: Int32) -> RuntimeError {
        .pollFailed(errno)
    }

    func pollEventFailed(revents: Int16) -> RuntimeError {
        .pollEventFailed(revents: revents)
    }
}
