import CWaylandClientSystem
import CWaylandProtocols
import Glibc

public enum RuntimeError: Error, CustomStringConvertible {
    case connectionFailed
    case registryCreationFailed
    case registryListenerInstallationFailed
    case displaySyncRequestFailed
    case frameRequestFailed
    case syncCallbackListenerInstallationFailed
    case missingRequiredGlobal(String)
    case bindFailed(String)
    case pollFailed(Int32)
    case pollEventFailed(revents: Int16)
    case systemError(errno: Int32)
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
        case .registryCreationFailed:
            "Wayland registry creation failed"
        case .registryListenerInstallationFailed:
            "Wayland registry listener installation failed"
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
        case .protocolError(let iface, let oid, let code):
            "Wayland protocol error interface=\(iface ?? "?") object=\(oid) code=\(code)"
        }
    }
}
