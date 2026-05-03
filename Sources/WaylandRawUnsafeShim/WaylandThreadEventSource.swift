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
    case executorNotReady
    case executorClosed
    case executorStopping(ShutdownMode)
    case executorStopped
    case executorFailedToStart(ExecutorStartFailure)
    case wakeFileDescriptorReadFailed(Int32)
    case wakeFileDescriptorShortRead(Int)
    case wakeFileDescriptorWriteFailed(Int32)
    case wakeFileDescriptorShortWrite(Int)
    case pollFailed(Int32)
    case pollEventFailed(revents: Int16)

    public var description: String {
        switch self {
        case .executorNotReady:
            "Wayland owner thread executor is not ready"
        case .executorClosed:
            "Wayland owner thread executor is closed"
        case .executorStopping(let mode):
            "Wayland owner thread executor is stopping (\(mode))"
        case .executorStopped:
            "Wayland owner thread executor has stopped"
        case .executorFailedToStart(let failure):
            "Wayland owner thread executor failed to start: \(failure)"
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
