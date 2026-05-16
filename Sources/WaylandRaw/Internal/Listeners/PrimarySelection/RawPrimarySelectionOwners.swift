import CWaylandProtocols

@safe
package struct RawPrimarySelectionOfferHandle: Equatable, Hashable, Sendable {
    package let rawValue: UInt

    package init(uncheckedRawValue offerRawValue: UInt) {
        precondition(
            offerRawValue != 0,
            "primary selection offer handle raw value must not be zero"
        )
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

@safe
package final class RawPrimarySelectionOfferOwner {
    private let onEvent: (RawPrimarySelectionOfferEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = ListenerInstallState.idle
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
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "zwp_primary_selection_offer_v1") {
            unsafe swl_primary_selection_offer_add_listener(
                offer.pointer,
                callbacks
            )
        }
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
                owner.onEvent(.offer(stringFromNullableCString(mimeType)))
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
    private var installState = ListenerInstallState.idle
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
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "zwp_primary_selection_source_v1") {
            unsafe swl_primary_selection_source_add_listener(
                source.pointer,
                callbacks
            )
        }
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
                owner.onEvent(.send(mimeType: stringFromNullableCString(mimeType), fd: fd))
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
    private var installState = ListenerInstallState.idle
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
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "zwp_primary_selection_device_v1") {
            unsafe swl_primary_selection_device_add_listener(
                device.pointer,
                callbacks
            )
        }
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
