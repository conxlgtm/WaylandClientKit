import Glibc

package protocol WaylandThreadEventSource: AnyObject {
    var isClosed: Bool { get }

    func fileDescriptor() throws -> CInt
    func dispatchPending() throws -> Int32
    func prepareRead() throws -> Bool
    func flush() throws -> Bool
    func readEvents() throws
    func cancelRead()

    func handleEventLoopError(_ error: any Error)
}

public enum WaylandThreadExecutorError: Error, Equatable, Sendable, CustomStringConvertible {
    case eventFileDescriptorCreationFailed(Int32)
    case threadCreationFailed(Int32)
    case executorClosed
    case wakeFileDescriptorReadFailed(Int32)
    case wakeFileDescriptorShortRead(Int)
    case wakeFileDescriptorWriteFailed(Int32)
    case wakeFileDescriptorShortWrite(Int)
    case pollFailed(Int32)
    case pollEventFailed(revents: Int16)

    public var description: String {
        switch self {
        case .eventFileDescriptorCreationFailed(let errorCode):
            "failed to create Wayland owner thread wake fd: eventfd failed with errno \(errorCode)"
        case .threadCreationFailed(let code):
            "failed to create Wayland owner thread: pthread_create returned \(code)"
        case .executorClosed:
            "Wayland owner thread executor is closed"
        case .wakeFileDescriptorReadFailed(let errorCode):
            "Wayland owner thread wake fd read failed with errno \(errorCode)"
        case .wakeFileDescriptorShortRead(let byteCount):
            "Wayland owner thread wake fd read returned \(byteCount) bytes"
        case .wakeFileDescriptorWriteFailed(let errorCode):
            "Wayland owner thread wake fd write failed with errno \(errorCode)"
        case .wakeFileDescriptorShortWrite(let byteCount):
            "Wayland owner thread wake fd write returned \(byteCount) bytes"
        case .pollFailed(let errorCode):
            "Wayland owner thread poll failed with errno \(errorCode)"
        case .pollEventFailed(let revents):
            "Wayland owner thread poll returned error events \(revents)"
        }
    }
}
