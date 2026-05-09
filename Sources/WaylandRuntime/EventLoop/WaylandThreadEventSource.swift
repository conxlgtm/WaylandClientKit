import Glibc
import WaylandRaw

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

package enum WaylandThreadExecutorError: Error, Equatable, Sendable, CustomStringConvertible {
    case executorNotReady
    case executorClosed
    case executorStopping(ShutdownMode)
    case executorStopped
    case executorFailedToStart(ExecutorStartFailure)
    case operationSyncInitFailed(function: String, code: Int32)
    case wakeFileDescriptorReadFailed(Int32)
    case wakeFileDescriptorShortRead(Int)
    case wakeFileDescriptorWriteFailed(Int32)
    case wakeFileDescriptorShortWrite(Int)
    case eventLoop(RawEventLoopError)

    package var description: String {
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
        case .operationSyncInitFailed(let function, let code):
            "\(function) for a synchronous executor operation returned \(code)"
        case .wakeFileDescriptorReadFailed(let errorCode):
            "Wayland owner thread wake fd read failed with errno \(errorCode)"
        case .wakeFileDescriptorShortRead(let byteCount):
            "Wayland owner thread wake fd read returned \(byteCount) bytes"
        case .wakeFileDescriptorWriteFailed(let errorCode):
            "Wayland owner thread wake fd write failed with errno \(errorCode)"
        case .wakeFileDescriptorShortWrite(let byteCount):
            "Wayland owner thread wake fd write returned \(byteCount) bytes"
        case .eventLoop(let error):
            "Wayland owner thread event loop failed: \(error.description)"
        }
    }
}
