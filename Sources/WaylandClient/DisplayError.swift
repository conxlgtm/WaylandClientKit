import WaylandRaw
import WaylandRawUnsafeShim

public enum WaylandProtocolError: Equatable, Sendable, CustomStringConvertible {
    case display(interface: String?, objectID: UInt32, code: Int32)
    case invalidXDGConfigureDimensions(windowID: WindowID, width: Int32, height: Int32)
    case invalidConfigureSerial(windowID: WindowID, serial: UInt32)
    case proxyQueueMismatch(interface: String, objectID: RawObjectID?)

    public var description: String {
        switch self {
        case .display(let interface, let objectID, let code):
            "Wayland protocol error interface=\(interface ?? "?") object=\(objectID) code=\(code)"
        case .invalidXDGConfigureDimensions(let windowID, let width, let height):
            "Window \(windowID) received invalid XDG configure dimensions "
                + "width=\(width) height=\(height)"
        case .invalidConfigureSerial(let windowID, let serial):
            "Window \(windowID) received invalid configure serial \(serial)"
        case .proxyQueueMismatch(let interface, let objectID):
            "Wayland proxy queue mismatch interface=\(interface) object="
                + "\(objectID?.description ?? "?")"
        }
    }
}

public enum WaylandEventLoopError: Equatable, Sendable, CustomStringConvertible {
    case unexpectedDisplayRevents(revents: Int16)
    case unexpectedWakeRevents(revents: Int16)

    public var description: String {
        switch self {
        case .unexpectedDisplayRevents(let revents):
            "Wayland display poll returned error events \(revents)"
        case .unexpectedWakeRevents(let revents):
            "Wayland wake poll returned error events \(revents)"
        }
    }
}

public enum InternalInvariantViolation: Equatable, Sendable, CustomStringConvertible {
    case message(String)
    case rawListenerFiredAfterInvalidation(String)
    case frameCallbackAfterLocalDestroy(WindowID)
    case bufferReleaseWithoutBufferState(WindowID)
    case invalidWindowTransition(WindowID, transition: WindowLifecycleTransitionError)
    case effectInterpreterInvariant(WindowID, String)
    case unexpectedWindowCallbackError(
        WindowID,
        operation: WindowCallbackOperation,
        detail: String
    )
    case eventSubscriberAwaitedTwice

    public var description: String {
        switch self {
        case .message(let detail):
            detail
        case .rawListenerFiredAfterInvalidation(let detail):
            "Raw listener fired after invalidation: \(detail)"
        case .frameCallbackAfterLocalDestroy(let windowID):
            "Frame callback fired after local destroy for window \(windowID)"
        case .bufferReleaseWithoutBufferState(let windowID):
            "Buffer release arrived without buffer state for window \(windowID)"
        case .invalidWindowTransition(let windowID, let transition):
            "Window \(windowID) invalid transition: \(transition.description)"
        case .effectInterpreterInvariant(let windowID, let detail):
            "Window \(windowID) effect interpreter invariant failed: \(detail)"
        case .unexpectedWindowCallbackError(let windowID, let operation, let detail):
            "Window \(windowID) callback \(operation) failed unexpectedly: \(detail)"
        case .eventSubscriberAwaitedTwice:
            "event subscriber awaited twice"
        }
    }
}

public enum WaylandDisplayError: Error, Equatable, Sendable, CustomStringConvertible {
    case closed
    case protocolError(WaylandProtocolError)
    case systemError(RawSystemError)
    case eventLoopError(WaylandEventLoopError)
    case eventSubscriberOverflow(stream: EventStreamIdentity, capacity: Int)
    case inputPipelineOverflow(InputPipelineOverflow)
    case internalInvariantViolation(InternalInvariantViolation)

    init(_ runtimeError: RuntimeError) {
        switch runtimeError {
        case .protocolError(let error):
            self = .protocolError(
                .display(
                    interface: error.interfaceName,
                    objectID: error.objectID,
                    code: error.code
                )
            )
        case .proxy(.queueMismatch(let interface, let objectID)):
            self = .protocolError(.proxyQueueMismatch(interface: interface, objectID: objectID))
        case .eventLoop(let error):
            self = Self(error)
        case .system(let error):
            self = .systemError(error)
        case .systemErrnoUnavailable:
            self = .internalInvariantViolation(.message(runtimeError.description))
        case .connectionFailed,
            .eventQueueCreationFailed,
            .displayWrapperCreationFailed,
            .registryCreationFailed,
            .listener,
            .displaySyncRequestFailed,
            .frameRequestFailed,
            .missingRequiredGlobal,
            .bindFailed,
            .operationTimedOut,
            .shortRead,
            .invalidWaylandArrayByteCount:
            self = .internalInvariantViolation(.message(runtimeError.description))
        }
    }

    init(_ executorError: WaylandThreadExecutorError) {
        switch executorError {
        case .eventLoop(let error):
            self = Self(error)
        case .executorNotReady,
            .executorClosed,
            .executorStopping,
            .executorStopped,
            .executorFailedToStart,
            .wakeFileDescriptorReadFailed,
            .wakeFileDescriptorShortRead,
            .wakeFileDescriptorWriteFailed,
            .wakeFileDescriptorShortWrite:
            self = .internalInvariantViolation(.message(executorError.description))
        }
    }

    init(_ eventLoopError: RawEventLoopError) {
        switch eventLoopError {
        case .system(let error):
            self = .systemError(error)
        case .unexpectedDisplayRevents(let revents):
            self = .eventLoopError(.unexpectedDisplayRevents(revents: revents))
        case .unexpectedWakeRevents(let revents):
            self = .eventLoopError(.unexpectedWakeRevents(revents: revents))
        }
    }

    public var description: String {
        switch self {
        case .closed:
            "Wayland display is closed"
        case .protocolError(let error):
            error.description
        case .systemError(let error):
            "Wayland display failed: \(error.description)"
        case .eventLoopError(let error):
            error.description
        case .eventSubscriberOverflow(let stream, let capacity):
            "Wayland \(stream.description) subscriber exceeded buffer capacity \(capacity)"
        case .inputPipelineOverflow(let overflow):
            "Wayland input pipeline overflowed in \(overflow.stage.description) "
                + "at capacity \(overflow.capacity)"
        case .internalInvariantViolation(let violation):
            "Wayland display internal invariant failed: \(violation.description)"
        }
    }
}
