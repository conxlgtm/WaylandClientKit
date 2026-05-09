import CWaylandProtocols
import Glibc

@safe
package struct RawPrimarySelectionOfferHandle: Equatable, Hashable, Sendable {
    package let rawValue: UInt

    package init(uncheckedRawValue offerRawValue: UInt) {
        rawValue = offerRawValue
    }

    package init?(_ offerPointer: OpaquePointer?) {
        guard let offerPointer = unsafe offerPointer else {
            return nil
        }

        rawValue = UInt(bitPattern: offerPointer)
    }

    package var pointer: OpaquePointer? {
        unsafe OpaquePointer(bitPattern: rawValue)
    }
}

package enum RawPrimarySelectionOfferEvent: Equatable, Sendable {
    case offer(String?)
}

package enum RawPrimarySelectionSourceEvent: Equatable, Sendable {
    case send(mimeType: String?, fd: Int32)
    case cancelled
}

package enum RawPrimarySelectionDeviceEvent: Equatable, Sendable {
    case dataOffer(RawPrimarySelectionOfferHandle?)
    case selection(RawPrimarySelectionOfferHandle?)
}

private enum PrimarySelectionListenerInstallState {
    case idle
    case installed
}

@safe
package final class RawPrimarySelectionOfferOwner {
    private let onEvent: (RawPrimarySelectionOfferEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = PrimarySelectionListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_primary_selection_offer_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<
            swl_primary_selection_offer_listener_callbacks
        >
    {
        listenerStorage.callbacks
    }

    package init(
        onEvent eventHandler: @escaping (RawPrimarySelectionOfferEvent) -> Void,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        onEvent = eventHandler
        invariantFailureSink = failureSink
        configureCallbacks()
    }

    package func install(on offer: RawPrimarySelectionOffer) throws {
        guard installState == .idle else {
            throw listenerInstallError("zwp_primary_selection_offer_v1")
        }

        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_primary_selection_offer_add_listener(
            offer.pointer,
            callbacks
        )

        guard result == 0 else {
            throw listenerInstallError("zwp_primary_selection_offer_v1")
        }

        installState = .installed
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    private func configureCallbacks() {
        unsafe callbacks.pointee.offer = { data, _, mimeType in
            RawPrimarySelectionOfferOwner.withOwner(
                data,
                message: "zwp_primary_selection_offer_v1 offer fired without Swift state"
            ) { owner in
                owner.onEvent(.offer(optionalString(from: mimeType)))
            }
        }
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawPrimarySelectionOfferOwner) -> Void
    ) {
        CListenerStorage<
            RawPrimarySelectionOfferOwner,
            swl_primary_selection_offer_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}

@safe
package final class RawPrimarySelectionSourceOwner {
    private let onEvent: (RawPrimarySelectionSourceEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = PrimarySelectionListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_primary_selection_source_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<
            swl_primary_selection_source_listener_callbacks
        >
    {
        listenerStorage.callbacks
    }

    package init(
        onEvent eventHandler: @escaping (RawPrimarySelectionSourceEvent) -> Void,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        onEvent = eventHandler
        invariantFailureSink = failureSink
        configureCallbacks()
    }

    package func install(on source: RawPrimarySelectionSource) throws {
        guard installState == .idle else {
            throw listenerInstallError("zwp_primary_selection_source_v1")
        }

        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_primary_selection_source_add_listener(
            source.pointer,
            callbacks
        )

        guard result == 0 else {
            throw listenerInstallError("zwp_primary_selection_source_v1")
        }

        installState = .installed
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    private func configureCallbacks() {
        unsafe callbacks.pointee.send = { data, _, mimeType, fd in
            RawPrimarySelectionSourceOwner.withOwner(
                data,
                message: "zwp_primary_selection_source_v1 send fired without Swift state"
            ) { owner in
                owner.onEvent(.send(mimeType: optionalString(from: mimeType), fd: fd))
            }
        }
        unsafe callbacks.pointee.cancelled = { data, _ in
            RawPrimarySelectionSourceOwner.withOwner(
                data,
                message: "zwp_primary_selection_source_v1 cancelled fired without Swift state"
            ) { owner in
                owner.onEvent(.cancelled)
            }
        }
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawPrimarySelectionSourceOwner) -> Void
    ) {
        CListenerStorage<
            RawPrimarySelectionSourceOwner,
            swl_primary_selection_source_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}

@safe
package final class RawPrimarySelectionDeviceOwner {
    private let onEvent: (RawPrimarySelectionDeviceEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = PrimarySelectionListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_primary_selection_device_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<
            swl_primary_selection_device_listener_callbacks
        >
    {
        listenerStorage.callbacks
    }

    package init(
        onEvent eventHandler: @escaping (RawPrimarySelectionDeviceEvent) -> Void,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        onEvent = eventHandler
        invariantFailureSink = failureSink
        configureCallbacks()
    }

    package func install(on device: RawPrimarySelectionDevice) throws {
        guard installState == .idle else {
            throw listenerInstallError("zwp_primary_selection_device_v1")
        }

        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_primary_selection_device_add_listener(
            device.pointer,
            callbacks
        )

        guard result == 0 else {
            throw listenerInstallError("zwp_primary_selection_device_v1")
        }

        installState = .installed
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    private func configureCallbacks() {
        unsafe callbacks.pointee.data_offer = { data, _, offer in
            RawPrimarySelectionDeviceOwner.withOwner(
                data,
                message: "zwp_primary_selection_device_v1 data_offer fired without Swift state"
            ) { owner in
                owner.onEvent(.dataOffer(unsafe RawPrimarySelectionOfferHandle(offer)))
            }
        }
        unsafe callbacks.pointee.selection = { data, _, offer in
            RawPrimarySelectionDeviceOwner.withOwner(
                data,
                message: "zwp_primary_selection_device_v1 selection fired without Swift state"
            ) { owner in
                owner.onEvent(.selection(unsafe RawPrimarySelectionOfferHandle(offer)))
            }
        }
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawPrimarySelectionDeviceOwner) -> Void
    ) {
        CListenerStorage<
            RawPrimarySelectionDeviceOwner,
            swl_primary_selection_device_listener_callbacks
        >
        .withOwner(from: data, message: message(), body)
    }
}

private func listenerInstallError(_ interface: String) -> RuntimeError {
    RuntimeError.systemError(errno: EINVAL, operation: .installListener(interface))
}

@safe
private func optionalString(from cString: UnsafePointer<CChar>?) -> String? {
    unsafe cString.map { unsafe String(cString: $0) }
}
