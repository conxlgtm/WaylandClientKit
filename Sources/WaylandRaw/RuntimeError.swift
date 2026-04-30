import CWaylandClientSystem
import CWaylandProtocols
import Glibc

public enum RuntimeError: Error, Equatable, Sendable, CustomStringConvertible {
    case connectionFailed
    case eventQueueCreationFailed
    case displayWrapperCreationFailed
    case registryCreationFailed
    case registryListenerInstallationFailed
    case seatListenerInstallationFailed
    case pointerListenerInstallationFailed
    case keyboardListenerInstallationFailed
    case touchListenerInstallationFailed
    case displaySyncRequestFailed
    case frameRequestFailed
    case syncCallbackListenerInstallationFailed
    case missingRequiredGlobal(String)
    case bindFailed(String)
    case pollFailed(Int32)
    case pollEventFailed(revents: Int16)
    case systemError(errno: Int32)
    case operationTimedOut(String)
    case invalidKeymapSize(UInt32)
    case keymapTooLarge(size: UInt32, maxSize: UInt32)
    case keymapFdTooSmall(size: UInt32, actualSize: Int64)
    case keymapNotNullTerminated(size: UInt32)
    case invalidKeymapSizeLimit(maxSize: UInt32, hardMaximumSize: UInt32)
    case shortRead(expectedBytes: Int, actualBytes: Int)
    case invalidWaylandArrayByteCount(byteCount: Int, elementSize: Int)
    case protocolError(interfaceName: String?, objectID: UInt32, code: Int32)

    public static func fromDisplay(_ display: OpaquePointer, fallbackErrno: Int32? = nil)
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
            return .systemError(errno: error)
        }

        return .systemError(errno: fallbackErrno ?? 0)
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
        case .registryListenerInstallationFailed:
            "Wayland registry listener installation failed"
        case .seatListenerInstallationFailed:
            "Wayland seat listener installation failed"
        case .pointerListenerInstallationFailed:
            "Wayland pointer listener installation failed"
        case .keyboardListenerInstallationFailed:
            "Wayland keyboard listener installation failed"
        case .touchListenerInstallationFailed:
            "Wayland touch listener installation failed"
        case .displaySyncRequestFailed:
            "Wayland sync request failed"
        case .frameRequestFailed:
            "Wayland frame request failed"
        case .syncCallbackListenerInstallationFailed:
            "Wayland sync callback listener installation failed"
        case .missingRequiredGlobal(let name):
            "Missing required global: \(name)"
        case .bindFailed(let name):
            "Failed to bind global: \(name)"
        case .pollFailed(let errno):
            "poll failed with errno \(errno)"
        case .pollEventFailed(let revents):
            "poll returned error events \(revents)"
        case .systemError(let errno):
            "Wayland runtime failed with errno \(errno)"
        case .operationTimedOut(let detail):
            "Wayland runtime operation timed out: \(detail)"
        case .invalidKeymapSize(let size):
            "Invalid keyboard keymap size \(size)"
        case .keymapTooLarge(let size, let maxSize):
            "Keyboard keymap size \(size) exceeds maximum \(maxSize)"
        case .keymapFdTooSmall(let size, let actualSize):
            "Keyboard keymap advertised \(size) bytes but fd size is \(actualSize)"
        case .keymapNotNullTerminated(let size):
            "Keyboard keymap of size \(size) is not NUL-terminated"
        case .invalidKeymapSizeLimit(let maxSize, let hardMaximumSize):
            "Keyboard keymap size limit \(maxSize) exceeds hard maximum \(hardMaximumSize)"
        case .shortRead(let expectedBytes, let actualBytes):
            "Short read: expected \(expectedBytes) bytes, got \(actualBytes)"
        case .invalidWaylandArrayByteCount(let byteCount, let elementSize):
            "Wayland array byte count \(byteCount) is not divisible by \(elementSize)"
        case .protocolError(let iface, let oid, let code):
            "Wayland protocol error interface=\(iface ?? "?") object=\(oid) code=\(code)"
        }
    }
}
