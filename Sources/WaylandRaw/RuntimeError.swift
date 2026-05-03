import CWaylandClientSystem
import CWaylandProtocols
import Glibc

public enum RawSystemErrorConstructionError: Error, Equatable, Sendable {
    case zeroErrno
}

public struct NonZeroErrno: Equatable, Sendable, CustomStringConvertible {
    public let rawValue: Int32

    public init(_ rawErrorNumber: Int32) throws {
        guard rawErrorNumber != 0 else {
            throw RawSystemErrorConstructionError.zeroErrno
        }

        rawValue = rawErrorNumber
    }

    package init(unchecked rawErrorNumber: Int32) {
        precondition(rawErrorNumber != 0, "errno 0 is not a system failure")
        rawValue = rawErrorNumber
    }

    public var description: String {
        "\(rawValue)"
    }
}

public enum RawSystemOperation: Equatable, Sendable, CustomStringConvertible {
    case validateArgument(String)
    case createSharedMemoryFile
    case resizeSharedMemoryFile
    case mapSharedMemory
    case createBuffer
    case installListener(String)
    case readMonotonicClock
    case pollEventLoop
    case displayFlush
    case displayReadEvents
    case displayDispatchPending
    case displayPrepareRead
    case displayError
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
        case .duplicateFileDescriptor:
            "duplicate file descriptor"
        case .closeFileDescriptor:
            "close file descriptor"
        }
    }
}

public struct RawSystemError: Error, Equatable, Sendable, CustomStringConvertible {
    public let errno: NonZeroErrno
    public let operation: RawSystemOperation

    public init(errno errorNumber: NonZeroErrno, operation systemOperation: RawSystemOperation) {
        errno = errorNumber
        operation = systemOperation
    }

    public init(
        validatingErrno errorNumber: Int32,
        operation systemOperation: RawSystemOperation
    ) throws {
        errno = try NonZeroErrno(errorNumber)
        operation = systemOperation
    }

    package init(uncheckedErrno errorNumber: Int32, operation systemOperation: RawSystemOperation) {
        errno = NonZeroErrno(unchecked: errorNumber)
        operation = systemOperation
    }

    public var description: String {
        "\(operation.description) failed with errno \(errno.rawValue)"
    }
}

public struct RawProtocolError: Error, Equatable, Sendable, CustomStringConvertible {
    public let interfaceName: String?
    public let objectID: UInt32
    public let code: Int32

    public init(
        interfaceName protocolInterfaceName: String?,
        objectID protocolObjectID: UInt32,
        code protocolCode: Int32
    ) {
        interfaceName = protocolInterfaceName
        objectID = protocolObjectID
        code = protocolCode
    }

    public var description: String {
        "interface=\(interfaceName ?? "?") object=\(objectID) code=\(code)"
    }
}

public enum RawProxyError: Error, Equatable, Sendable, CustomStringConvertible {
    case queueMismatch(interface: String, objectID: RawObjectID?)

    public var description: String {
        switch self {
        case .queueMismatch(let interface, let objectID):
            "\(interface) proxy \(objectID.map(\.description) ?? "?") "
                + "is not assigned to the display owner event queue"
        }
    }
}

public enum RawListenerInstallationError: Error, Equatable, Sendable, CustomStringConvertible {
    case registry
    case seat
    case pointer
    case keyboard
    case touch
    case syncCallback

    public var description: String {
        switch self {
        case .registry:
            "Wayland registry listener installation failed"
        case .seat:
            "Wayland seat listener installation failed"
        case .pointer:
            "Wayland pointer listener installation failed"
        case .keyboard:
            "Wayland keyboard listener installation failed"
        case .touch:
            "Wayland touch listener installation failed"
        case .syncCallback:
            "Wayland sync callback listener installation failed"
        }
    }
}

public enum RawEventLoopError: Error, Equatable, Sendable, CustomStringConvertible {
    case system(RawSystemError)
    case unexpectedDisplayRevents(revents: Int16)
    case unexpectedWakeRevents(revents: Int16)

    public var description: String {
        switch self {
        case .system(let error):
            error.description
        case .unexpectedDisplayRevents(let revents):
            "Wayland display poll returned failure events \(revents)"
        case .unexpectedWakeRevents(let revents):
            "Wayland wake poll returned failure events \(revents)"
        }
    }
}

public enum RuntimeError: Error, Equatable, Sendable, CustomStringConvertible {
    case connectionFailed
    case eventQueueCreationFailed
    case displayWrapperCreationFailed
    case registryCreationFailed
    case listener(RawListenerInstallationError)
    case displaySyncRequestFailed
    case frameRequestFailed
    case missingRequiredGlobal(String)
    case bindFailed(String)
    case eventLoop(RawEventLoopError)
    case system(RawSystemError)
    case systemErrnoUnavailable(operation: RawSystemOperation)
    case operationTimedOut(String)
    case shortRead(expectedBytes: Int, actualBytes: Int)
    case invalidWaylandArrayByteCount(byteCount: Int, elementSize: Int)
    case protocolError(RawProtocolError)
    case proxy(RawProxyError)

    public static let registryListenerInstallationFailed: RuntimeError = .listener(.registry)
    public static let seatListenerInstallationFailed: RuntimeError = .listener(.seat)
    public static let pointerListenerInstallationFailed: RuntimeError = .listener(.pointer)
    public static let keyboardListenerInstallationFailed: RuntimeError = .listener(.keyboard)
    public static let touchListenerInstallationFailed: RuntimeError = .listener(.touch)
    public static let syncCallbackListenerInstallationFailed: RuntimeError =
        .listener(.syncCallback)

    public static func systemError(
        errno errorNumber: Int32,
        operation systemOperation: RawSystemOperation
    ) -> RuntimeError {
        guard errorNumber != 0 else {
            return .systemErrnoUnavailable(operation: systemOperation)
        }

        return .system(
            RawSystemError(uncheckedErrno: errorNumber, operation: systemOperation)
        )
    }

    public static func protocolError(
        interfaceName: String?,
        objectID: UInt32,
        code: Int32
    ) -> RuntimeError {
        .protocolError(
            RawProtocolError(
                interfaceName: interfaceName,
                objectID: objectID,
                code: code
            )
        )
    }

    public static func proxyQueueMismatch(_ interface: String) -> RuntimeError {
        .proxy(.queueMismatch(interface: interface, objectID: nil))
    }

    public static func fromDisplay(
        _ display: OpaquePointer,
        fallbackErrno: Int32? = nil,
        operation systemOperation: RawSystemOperation = .displayError
    )
        -> RuntimeError
    {
        let error = wl_display_get_error(display)

        if error == EPROTO {
            var details = swl_protocol_error_details(
                code: 0,
                object_id: 0,
                interface_name: nil
            )
            _ = swl_display_get_protocol_error_details(display, &details)

            return .protocolError(
                interfaceName: details.interface_name.map { String(cString: $0) },
                objectID: details.object_id,
                code: details.code
            )
        }

        if error != 0 {
            return .systemError(errno: error, operation: systemOperation)
        }

        guard let fallbackErrno, fallbackErrno != 0 else {
            return .systemErrnoUnavailable(operation: systemOperation)
        }

        return .systemError(errno: fallbackErrno, operation: systemOperation)
    }

    public var description: String {
        switch self {
        case .connectionFailed:
            "Wayland display connection failed"
        case .eventQueueCreationFailed:
            "Wayland event queue creation failed"
        case .displayWrapperCreationFailed:
            "Wayland display proxy wrapper creation failed"
        case .registryCreationFailed:
            "Wayland registry creation failed"
        case .listener(let error):
            error.description
        case .displaySyncRequestFailed:
            "Wayland sync request failed"
        case .frameRequestFailed:
            "Wayland frame request failed"
        case .missingRequiredGlobal(let name):
            "Missing required global: \(name)"
        case .bindFailed(let name):
            "Failed to bind global: \(name)"
        case .eventLoop(let error):
            error.description
        case .system(let error):
            "Wayland runtime failed with \(error.description)"
        case .systemErrnoUnavailable(let operation):
            "Wayland runtime failed during \(operation.description) without errno"
        case .operationTimedOut(let detail):
            "Wayland runtime operation timed out: \(detail)"
        case .shortRead(let expectedBytes, let actualBytes):
            "Short read: expected \(expectedBytes) bytes, got \(actualBytes)"
        case .invalidWaylandArrayByteCount(let byteCount, let elementSize):
            "Wayland array byte count \(byteCount) is not divisible by \(elementSize)"
        case .protocolError(let error):
            "Wayland protocol error \(error.description)"
        case .proxy(let error):
            error.description
        }
    }
}
