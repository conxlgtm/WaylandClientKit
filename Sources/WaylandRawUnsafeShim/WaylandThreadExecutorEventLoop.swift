import Glibc
import WaylandRaw

extension WaylandThreadExecutor {
    func runEventSourceTurn(
        _ source: any WaylandThreadEventSource,
        timeoutMilliseconds: Int32
    ) throws {
        try QueueEventLoopEngine().step(
            source: ExecutorEventLoopSource(source: source),
            timeoutMilliseconds: timeoutMilliseconds,
            wakeFileDescriptor: wakeFileDescriptor
        ) { [weak executor = self] in
            executor?.drainWakeFileDescriptor()
        }
    }
}

private struct ExecutorEventLoopSource: QueueEventLoopSource {
    typealias Failure = any Error

    let source: any WaylandThreadEventSource

    func dispatchPending() throws -> Int32 {
        try source.dispatchPending()
    }

    func prepareRead() throws -> Bool {
        try source.prepareRead()
    }

    func flush() throws -> Bool {
        try source.flush()
    }

    func fileDescriptor() throws -> CInt {
        try source.fileDescriptor()
    }

    func readEvents() throws {
        try source.readEvents()
    }

    func cancelRead() {
        source.cancelRead()
    }

    func pollFileDescriptors(
        _ descriptors: inout [pollfd],
        timeoutMilliseconds: Int32
    ) throws -> Int32 {
        unsafe descriptors.withUnsafeMutableBufferPointer { buffer in
            unsafe Glibc.poll(buffer.baseAddress, nfds_t(buffer.count), timeoutMilliseconds)
        }
    }

    func eventLoopFailed(_ error: RawEventLoopError) -> any Error {
        WaylandThreadExecutorError.eventLoop(error)
    }
}
