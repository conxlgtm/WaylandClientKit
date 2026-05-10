import CWaylandClientSystem
import CWaylandProtocols
import Glibc

package enum RawSystemErrorConstructionError: Error, Equatable, Sendable {
    case nonPositiveErrno(Int32)
}

package struct PositiveErrno: Equatable, Sendable, CustomStringConvertible {
    package let rawValue: Int32

    package init(_ rawErrorNumber: Int32) throws {
        guard rawErrorNumber > 0 else {
            throw RawSystemErrorConstructionError.nonPositiveErrno(rawErrorNumber)
        }

        rawValue = rawErrorNumber
    }

    package init(unchecked rawErrorNumber: Int32) {
        precondition(rawErrorNumber > 0, "errno must be positive")
        rawValue = rawErrorNumber
    }

    package var description: String {
        "\(rawValue)"
    }
}

package enum RawSystemOperation: Equatable, Sendable, CustomStringConvertible {
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

    package var description: String {
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

package struct RawSystemError: Error, Equatable, Sendable, CustomStringConvertible {
    package let errno: PositiveErrno
    package let operation: RawSystemOperation

    package init(errno errorNumber: PositiveErrno, operation systemOperation: RawSystemOperation) {
        errno = errorNumber
        operation = systemOperation
    }

    package init(
        validatingErrno errorNumber: Int32,
        operation systemOperation: RawSystemOperation
    ) throws {
        errno = try PositiveErrno(errorNumber)
        operation = systemOperation
    }

    package init(uncheckedErrno errorNumber: Int32, operation systemOperation: RawSystemOperation) {
        errno = PositiveErrno(unchecked: errorNumber)
        operation = systemOperation
    }

    package var description: String {
        "\(operation.description) failed with errno \(errno.rawValue)"
    }
}

package struct RawProtocolError: Error, Equatable, Sendable, CustomStringConvertible {
    package let interfaceName: String?
    package let objectID: UInt32
    package let code: Int32

    package init(
        interfaceName protocolInterfaceName: String?,
        objectID protocolObjectID: UInt32,
        code protocolCode: Int32
    ) {
        interfaceName = protocolInterfaceName
        objectID = protocolObjectID
        code = protocolCode
    }

    package var description: String {
        "interface=\(interfaceName ?? "?") object=\(objectID) code=\(code)"
    }
}

package enum RawProxyError: Error, Equatable, Sendable, CustomStringConvertible {
    case queueMismatch(interface: String, objectID: RawObjectID?)

    package var description: String {
        switch self {
        case .queueMismatch(let interface, let objectID):
            "\(interface) proxy \(objectID.map(\.description) ?? "?") "
                + "is not assigned to the display owner event queue"
        }
    }
}

package enum RawListenerInstallationError: Error, Equatable, Sendable, CustomStringConvertible {
    case registry
    case output
    case seat
    case pointer
    case keyboard
    case touch
    case syncCallback

    package var description: String {
        switch self {
        case .registry:
            "Wayland registry listener installation failed"
        case .output:
            "Wayland output listener installation failed"
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

package enum RawEventLoopError: Error, Equatable, Sendable, CustomStringConvertible {
    case system(RawSystemError)
    case unexpectedDisplayRevents(revents: Int16)
    case unexpectedWakeRevents(revents: Int16)

    package var description: String {
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

package enum RuntimeError: Error, Equatable, Sendable, CustomStringConvertible {
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
    case invalidDecorationMode(UInt32)
    case invalidTopLevelConfigureSize(width: Int32, height: Int32)
    case invalidConfigureBounds(width: Int32, height: Int32)
    case protocolError(RawProtocolError)
    case proxy(RawProxyError)

    package static let registryListenerInstallationFailed: RuntimeError = .listener(.registry)
    package static let outputListenerInstallationFailed: RuntimeError = .listener(.output)
    package static let seatListenerInstallationFailed: RuntimeError = .listener(.seat)
    package static let pointerListenerInstallationFailed: RuntimeError = .listener(.pointer)
    package static let keyboardListenerInstallationFailed: RuntimeError = .listener(.keyboard)
    package static let touchListenerInstallationFailed: RuntimeError = .listener(.touch)
    package static let syncCallbackListenerInstallationFailed: RuntimeError =
        .listener(.syncCallback)

    package static func systemError(
        errno errorNumber: Int32,
        operation systemOperation: RawSystemOperation
    ) -> RuntimeError {
        guard errorNumber > 0 else {
            return .systemErrnoUnavailable(operation: systemOperation)
        }

        return .system(
            RawSystemError(uncheckedErrno: errorNumber, operation: systemOperation)
        )
    }

    package static func protocolError(
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

    package static func proxyQueueMismatch(_ interface: String) -> RuntimeError {
        .proxy(.queueMismatch(interface: interface, objectID: nil))
    }

    @safe
    package static func fromDisplay(
        _ display: OpaquePointer,
        fallbackErrno: Int32? = nil,
        operation systemOperation: RawSystemOperation = .displayError
    )
        -> RuntimeError
    {
        let error = unsafe wl_display_get_error(display)

        if error == EPROTO {
            var details = unsafe swl_protocol_error_details(
                code: 0,
                object_id: 0,
                interface_name: nil
            )
            _ = unsafe swl_display_get_protocol_error_details(display, &details)

            return unsafe .protocolError(
                interfaceName: details.interface_name.map { unsafe String(cString: $0) },
                objectID: details.object_id,
                code: details.code
            )
        }

        if error != 0 {
            return .systemError(errno: error, operation: systemOperation)
        }

        guard let fallbackErrno, fallbackErrno > 0 else {
            return .systemErrnoUnavailable(operation: systemOperation)
        }

        return .systemError(errno: fallbackErrno, operation: systemOperation)
    }

    package var description: String {
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
        case .invalidDecorationMode(let rawValue):
            "Invalid zxdg_toplevel_decoration_v1 mode \(rawValue)"
        case .invalidTopLevelConfigureSize(let width, let height):
            "Invalid xdg_toplevel.configure size \(width)x\(height)"
        case .invalidConfigureBounds(let width, let height):
            "Invalid xdg_toplevel.configure_bounds \(width)x\(height)"
        case .protocolError(let error):
            "Wayland protocol error \(error.description)"
        case .proxy(let error):
            error.description
        }
    }
}
