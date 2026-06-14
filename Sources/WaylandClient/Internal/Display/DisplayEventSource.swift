import WaylandRaw
import WaylandRuntime

@safe
final class DisplayEventSource: WaylandThreadEventSource {
    private let core: DisplayCore

    init(core displayCore: DisplayCore) {
        core = displayCore
    }

    var isClosed: Bool {
        core.isClosed
    }

    func fileDescriptor() throws -> CInt {
        try core.fileDescriptor()
    }

    func dispatchPending() throws -> Int32 {
        try core.dispatchPending()
    }

    func prepareRead() throws -> Bool {
        try core.prepareRead()
    }

    func flush() throws -> Bool {
        try core.flush()
    }

    func readEvents() throws {
        try core.readEvents()
    }

    func cancelRead() {
        core.cancelRead()
    }

    func handleEventLoopError(_ error: any Error) {
        core.fail(displayError(for: error))
    }

    private func displayError(for error: any Error) -> WaylandDisplayError {
        if let displayError = error as? WaylandDisplayError {
            return displayError
        }

        if let runtimeError = error as? RuntimeError {
            return WaylandDisplayError(runtimeError)
        }

        if let executorError = error as? WaylandThreadExecutorError {
            return WaylandDisplayError(executorError)
        }

        return .internalInvariantViolation(.message(String(describing: error)))
    }
}
