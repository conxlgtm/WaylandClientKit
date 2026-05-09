import WaylandRaw
import WaylandRuntime

public enum WaylandSystemErrorConstructionError: Error, Equatable, Sendable {
    case nonPositiveErrno(Int32)
}

public struct WaylandSystemErrno: Equatable, Sendable, CustomStringConvertible {
    public let rawValue: Int32

    public init(_ rawErrorNumber: Int32) throws {
        guard rawErrorNumber > 0 else {
            throw WaylandSystemErrorConstructionError.nonPositiveErrno(rawErrorNumber)
        }

        rawValue = rawErrorNumber
    }

    package init(unchecked rawErrorNumber: Int32) {
        precondition(rawErrorNumber > 0, "errno must be positive")
        rawValue = rawErrorNumber
    }

    public var description: String {
        "\(rawValue)"
    }
}

public enum WaylandSystemOperation: Equatable, Sendable, CustomStringConvertible {
    case validateArgument(String)
    case createSharedMemoryFile
    case resizeSharedMemoryFile
    case mapSharedMemory
    case createBuffer
    case installListener(String)
    case connectDisplay
    case readMonotonicClock
    case pollEventLoop
    case displayFlush
    case displayReadEvents
    case displayDispatchPending
    case displayPrepareRead
    case displayError
    case keymapFstat
    case keymapMmap
    case createPipe
    case readFileDescriptor
    case writeFileDescriptor
    case duplicateFileDescriptor
    case closeFileDescriptor

    public var description: String {
        switch self {
        case .validateArgument(let name):
            "validate \(name)"
        case .createSharedMemoryFile:
            "create shared memory file"
        case .resizeSharedMemoryFile:
            "resize shared memory file"
        case .mapSharedMemory:
            "map shared memory"
        case .createBuffer:
            "create Wayland buffer"
        case .installListener(let name):
            "install \(name) listener"
        case .connectDisplay:
            "connect Wayland display"
        case .readMonotonicClock:
            "read monotonic clock"
        case .pollEventLoop:
            "poll Wayland event loop"
        case .displayFlush:
            "flush Wayland display"
        case .displayReadEvents:
            "read Wayland display events"
        case .displayDispatchPending:
            "dispatch pending Wayland events"
        case .displayPrepareRead:
            "prepare Wayland display read"
        case .displayError:
            "read Wayland display error"
        case .keymapFstat:
            "inspect keyboard keymap file"
        case .keymapMmap:
            "map keyboard keymap file"
        case .createPipe:
            "create pipe"
        case .readFileDescriptor:
            "read file descriptor"
        case .writeFileDescriptor:
            "write file descriptor"
        case .duplicateFileDescriptor:
            "duplicate file descriptor"
        case .closeFileDescriptor:
            "close file descriptor"
        }
    }
}

extension WaylandSystemOperation {
    package init(_ rawOperation: RawSystemOperation) {
        switch rawOperation {
        case .validateArgument, .installListener:
            self = Self.namedOperation(rawOperation)
        case .createSharedMemoryFile, .resizeSharedMemoryFile, .mapSharedMemory, .createBuffer:
            self = Self.sharedMemoryOperation(rawOperation)
        case .connectDisplay, .readMonotonicClock, .pollEventLoop:
            self = Self.runtimeOperation(rawOperation)
        case .displayFlush, .displayReadEvents, .displayDispatchPending,
            .displayPrepareRead, .displayError:
            self = Self.displayOperation(rawOperation)
        case .keymapFstat, .keymapMmap:
            self = Self.keymapOperation(rawOperation)
        case .createPipe, .readFileDescriptor, .writeFileDescriptor, .duplicateFileDescriptor,
            .closeFileDescriptor:
            self = Self.fileDescriptorOperation(rawOperation)
        }
    }

    private static func namedOperation(
        _ rawOperation: RawSystemOperation
    ) -> WaylandSystemOperation {
        switch rawOperation {
        case .validateArgument(let name):
            .validateArgument(name)
        case .installListener(let name):
            .installListener(name)
        default:
            preconditionFailure("operation is not name-bearing")
        }
    }

    private static func sharedMemoryOperation(
        _ rawOperation: RawSystemOperation
    ) -> WaylandSystemOperation {
        switch rawOperation {
        case .createSharedMemoryFile:
            .createSharedMemoryFile
        case .resizeSharedMemoryFile:
            .resizeSharedMemoryFile
        case .mapSharedMemory:
            .mapSharedMemory
        case .createBuffer:
            .createBuffer
        default:
            preconditionFailure("operation is not shared-memory related")
        }
    }

    private static func runtimeOperation(
        _ rawOperation: RawSystemOperation
    ) -> WaylandSystemOperation {
        switch rawOperation {
        case .connectDisplay:
            .connectDisplay
        case .readMonotonicClock:
            .readMonotonicClock
        case .pollEventLoop:
            .pollEventLoop
        default:
            preconditionFailure("operation is not runtime related")
        }
    }

    private static func displayOperation(
        _ rawOperation: RawSystemOperation
    ) -> WaylandSystemOperation {
        switch rawOperation {
        case .displayFlush:
            .displayFlush
        case .displayReadEvents:
            .displayReadEvents
        case .displayDispatchPending:
            .displayDispatchPending
        case .displayPrepareRead:
            .displayPrepareRead
        case .displayError:
            .displayError
        default:
            preconditionFailure("operation is not display related")
        }
    }

    private static func keymapOperation(
        _ rawOperation: RawSystemOperation
    ) -> WaylandSystemOperation {
        switch rawOperation {
        case .keymapFstat:
            .keymapFstat
        case .keymapMmap:
            .keymapMmap
        default:
            preconditionFailure("operation is not keymap related")
        }
    }

    private static func fileDescriptorOperation(
        _ rawOperation: RawSystemOperation
    ) -> WaylandSystemOperation {
        switch rawOperation {
        case .createPipe:
            .createPipe
        case .readFileDescriptor:
            .readFileDescriptor
        case .writeFileDescriptor:
            .writeFileDescriptor
        case .duplicateFileDescriptor:
            .duplicateFileDescriptor
        case .closeFileDescriptor:
            .closeFileDescriptor
        default:
            preconditionFailure("operation is not file-descriptor related")
        }
    }
}

public struct WaylandSystemError: Error, Equatable, Sendable, CustomStringConvertible {
    public let errno: WaylandSystemErrno
    public let operation: WaylandSystemOperation

    public init(
        errno errorNumber: WaylandSystemErrno,
        operation systemOperation: WaylandSystemOperation
    ) {
        errno = errorNumber
        operation = systemOperation
    }

    public init(
        validatingErrno errorNumber: Int32,
        operation systemOperation: WaylandSystemOperation
    ) throws {
        errno = try WaylandSystemErrno(errorNumber)
        operation = systemOperation
    }

    package init(_ rawError: RawSystemError) {
        errno = WaylandSystemErrno(unchecked: rawError.errno.rawValue)
        operation = WaylandSystemOperation(rawError.operation)
    }

    public var description: String {
        "\(operation.description) failed with errno \(errno.rawValue)"
    }
}

public struct WaylandProtocolObjectID: Equatable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue objectRawValue: UInt32) {
        rawValue = objectRawValue
    }

    package init(_ objectID: RawObjectID) {
        rawValue = objectID.value
    }

    public var description: String {
        "\(rawValue)"
    }
}

public enum WaylandProtocolError: Equatable, Sendable, CustomStringConvertible {
    case display(interface: String?, objectID: UInt32, code: Int32)
    case invalidXDGConfigureDimensions(windowID: WindowID, width: Int32, height: Int32)
    case invalidXDGTopLevelConfigureSize(width: Int32, height: Int32)
    case invalidXDGConfigureBounds(width: Int32, height: Int32)
    case invalidConfigureSerial(windowID: WindowID, serial: UInt32)
    case invalidDecorationMode(rawValue: UInt32)
    case invalidPreferredBufferScale(windowID: WindowID, factor: Int32)
    case invalidFractionalScale(windowID: WindowID, numerator: UInt32)
    case unrepresentableSurfaceBufferSize(
        windowID: WindowID,
        logicalDimension: Int32,
        scaleNumerator: UInt32,
        scaleDenominator: UInt32
    )
    case proxyQueueMismatch(interface: String, objectID: WaylandProtocolObjectID?)

    public var description: String {
        switch self {
        case .display(let interface, let objectID, let code):
            "Wayland protocol error interface=\(interface ?? "?") object=\(objectID) code=\(code)"
        case .invalidXDGConfigureDimensions(let windowID, let width, let height):
            "Window \(windowID) received invalid XDG configure dimensions "
                + "width=\(width) height=\(height)"
        case .invalidXDGTopLevelConfigureSize(let width, let height):
            "Received invalid XDG top-level configure size width=\(width) height=\(height)"
        case .invalidXDGConfigureBounds(let width, let height):
            "Received invalid XDG configure bounds width=\(width) height=\(height)"
        case .invalidConfigureSerial(let windowID, let serial):
            "Window \(windowID) received invalid configure serial \(serial)"
        case .invalidDecorationMode(let rawValue):
            "Received invalid zxdg_toplevel_decoration_v1 mode \(rawValue)"
        case .invalidPreferredBufferScale(let windowID, let factor):
            "Window \(windowID) received invalid wl_surface preferred buffer scale "
                + "\(factor)"
        case .invalidFractionalScale(let windowID, let numerator):
            "Window \(windowID) received invalid wp_fractional_scale_v1 preferred scale "
                + "\(numerator)"
        case .unrepresentableSurfaceBufferSize(
            let windowID,
            let logicalDimension,
            let scaleNumerator,
            let scaleDenominator
        ):
            "Window \(windowID) surface scale \(scaleNumerator)/\(scaleDenominator) makes "
                + "logical dimension \(logicalDimension) unrepresentable as an Int32 buffer "
                + "dimension"
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
    case systemError(WaylandSystemError)
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
            self = .protocolError(
                .proxyQueueMismatch(
                    interface: interface,
                    objectID: objectID.map(WaylandProtocolObjectID.init)
                )
            )
        case .invalidDecorationMode(let rawValue):
            self = .protocolError(.invalidDecorationMode(rawValue: rawValue))
        case .invalidTopLevelConfigureSize(let width, let height):
            self = .protocolError(.invalidXDGTopLevelConfigureSize(width: width, height: height))
        case .invalidConfigureBounds(let width, let height):
            self = .protocolError(.invalidXDGConfigureBounds(width: width, height: height))
        case .eventLoop(let error):
            self = Self(error)
        case .system(let error):
            self = .systemError(WaylandSystemError(error))
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
            .operationSyncInitFailed,
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
            self = .systemError(WaylandSystemError(error))
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
