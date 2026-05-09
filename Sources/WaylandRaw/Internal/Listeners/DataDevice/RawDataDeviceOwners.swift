import CWaylandProtocols
import Glibc

@safe
package struct RawDataOfferHandle: Equatable, Hashable, Sendable {
    package let rawValue: UInt

    package init(uncheckedRawValue offerRawValue: UInt) {
        precondition(offerRawValue != 0, "data offer handle raw value must not be zero")
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

package enum RawDataOfferEvent: Equatable, Sendable {
    case offer(String?)
    case sourceActions(RawDataDeviceDNDAction)
    case action(RawDataDeviceDNDAction)
}

package enum RawDataSourceEvent: Equatable, Sendable {
    case target(String?)
    case send(mimeType: String?, fd: Int32)
    case cancelled
    case dndDropPerformed
    case dndFinished
    case action(RawDataDeviceDNDAction)
}

@safe
package struct RawDataDeviceEnter: Equatable {
    package let serial: UInt32
    @safe package let surface: OpaquePointer?
    package let x: WaylandFixed
    package let y: WaylandFixed
    package let offer: RawDataOfferHandle?

    package init(
        serial eventSerial: UInt32,
        surface surfacePointer: OpaquePointer?,
        x positionX: WaylandFixed,
        y positionY: WaylandFixed,
        offer offerHandle: RawDataOfferHandle?
    ) {
        serial = eventSerial
        unsafe surface = surfacePointer
        x = positionX
        y = positionY
        offer = offerHandle
    }

    package static func == (lhs: RawDataDeviceEnter, rhs: RawDataDeviceEnter) -> Bool {
        lhs.serial == rhs.serial
            && (unsafe lhs.surface == rhs.surface)
            && lhs.x == rhs.x
            && lhs.y == rhs.y
            && lhs.offer == rhs.offer
    }
}

package enum RawDataDeviceEvent: Equatable {
    case dataOffer(RawDataOfferHandle?)
    case enter(RawDataDeviceEnter)
    case leave
    case motion(time: UInt32, x: WaylandFixed, y: WaylandFixed)
    case drop
    case selection(RawDataOfferHandle?)
}

private enum DataDeviceListenerInstallState {
    case idle
    case installed
}

@safe
package final class RawDataOfferOwner {
    private let onEvent: (RawDataOfferEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = DataDeviceListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_data_offer_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_data_offer_listener_callbacks> {
        listenerStorage.callbacks
    }

    package init(
        onEvent eventHandler: @escaping (RawDataOfferEvent) -> Void,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        onEvent = eventHandler
        invariantFailureSink = failureSink
        configureCallbacks()
    }

    package func install(on offer: RawDataOffer) throws {
        guard installState == .idle else {
            throw listenerInstallError("wl_data_offer")
        }

        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_data_offer_add_listener(offer.pointer, callbacks)

        guard result == 0 else {
            throw listenerInstallError("wl_data_offer")
        }

        installState = .installed
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    private func configureCallbacks() {
        unsafe callbacks.pointee.offer = { data, _, mimeType in
            RawDataOfferOwner.withOwner(
                data,
                message: "wl_data_offer offer fired without Swift state"
            ) { owner in
                owner.onEvent(.offer(optionalString(from: mimeType)))
            }
        }
        unsafe callbacks.pointee.source_actions = { data, _, actions in
            RawDataOfferOwner.withOwner(
                data,
                message: "wl_data_offer source_actions fired without Swift state"
            ) { owner in
                owner.onEvent(.sourceActions(.init(rawValue: actions)))
            }
        }
        unsafe callbacks.pointee.action = { data, _, action in
            RawDataOfferOwner.withOwner(
                data,
                message: "wl_data_offer action fired without Swift state"
            ) { owner in
                owner.onEvent(.action(.init(rawValue: action)))
            }
        }
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawDataOfferOwner) -> Void
    ) {
        CListenerStorage<RawDataOfferOwner, swl_data_offer_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

@safe
package final class RawDataSourceOwner {
    private let onEvent: (RawDataSourceEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = DataDeviceListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_data_source_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_data_source_listener_callbacks> {
        listenerStorage.callbacks
    }

    package init(
        onEvent eventHandler: @escaping (RawDataSourceEvent) -> Void,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        onEvent = eventHandler
        invariantFailureSink = failureSink
        configureCallbacks()
    }

    package func install(on source: RawDataSource) throws {
        guard installState == .idle else {
            throw listenerInstallError("wl_data_source")
        }

        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_data_source_add_listener(source.pointer, callbacks)

        guard result == 0 else {
            throw listenerInstallError("wl_data_source")
        }

        installState = .installed
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    private func configureCallbacks() {
        unsafe callbacks.pointee.target = { data, _, mimeType in
            RawDataSourceOwner.withOwner(
                data,
                message: "wl_data_source target fired without Swift state"
            ) { owner in
                owner.onEvent(.target(optionalString(from: mimeType)))
            }
        }
        unsafe callbacks.pointee.send = { data, _, mimeType, fd in
            RawDataSourceOwner.withOwner(
                data,
                message: "wl_data_source send fired without Swift state"
            ) { owner in
                owner.onEvent(.send(mimeType: optionalString(from: mimeType), fd: fd))
            }
        }
        configureLifecycleCallbacks()
    }

    private func configureLifecycleCallbacks() {
        unsafe callbacks.pointee.cancelled = { data, _ in
            RawDataSourceOwner.withOwner(
                data,
                message: "wl_data_source cancelled fired without Swift state"
            ) { owner in
                owner.onEvent(.cancelled)
            }
        }
        unsafe callbacks.pointee.dnd_drop_performed = { data, _ in
            RawDataSourceOwner.withOwner(
                data,
                message: "wl_data_source dnd_drop_performed fired without Swift state"
            ) { owner in
                owner.onEvent(.dndDropPerformed)
            }
        }
        unsafe callbacks.pointee.dnd_finished = { data, _ in
            RawDataSourceOwner.withOwner(
                data,
                message: "wl_data_source dnd_finished fired without Swift state"
            ) { owner in
                owner.onEvent(.dndFinished)
            }
        }
        unsafe callbacks.pointee.action = { data, _, action in
            RawDataSourceOwner.withOwner(
                data,
                message: "wl_data_source action fired without Swift state"
            ) { owner in
                owner.onEvent(.action(.init(rawValue: action)))
            }
        }
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawDataSourceOwner) -> Void
    ) {
        CListenerStorage<RawDataSourceOwner, swl_data_source_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

@safe
package final class RawDataDeviceOwner {
    private let onEvent: (RawDataDeviceEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = DataDeviceListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_data_device_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_data_device_listener_callbacks> {
        listenerStorage.callbacks
    }

    package init(
        onEvent eventHandler: @escaping (RawDataDeviceEvent) -> Void,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        onEvent = eventHandler
        invariantFailureSink = failureSink
        configureCallbacks()
    }

    package func install(on device: RawDataDevice) throws {
        guard installState == .idle else {
            throw listenerInstallError("wl_data_device")
        }

        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = unsafe swl_data_device_add_listener(device.pointer, callbacks)

        guard result == 0 else {
            throw listenerInstallError("wl_data_device")
        }

        installState = .installed
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    private func configureCallbacks() {
        unsafe callbacks.pointee.data_offer = { data, _, offer in
            RawDataDeviceOwner.withOwner(
                data,
                message: "wl_data_device data_offer fired without Swift state"
            ) { owner in
                owner.onEvent(.dataOffer(unsafe RawDataOfferHandle(offer)))
            }
        }
        unsafe callbacks.pointee.enter = { data, _, serial, surface, x, y, offer in
            RawDataDeviceOwner.withOwner(
                data,
                message: "wl_data_device enter fired without Swift state"
            ) { owner in
                owner.onEvent(
                    .enter(
                        unsafe RawDataDeviceEnter(
                            serial: serial,
                            surface: unsafe surface,
                            x: WaylandFixed(rawValue: x),
                            y: WaylandFixed(rawValue: y),
                            offer: unsafe RawDataOfferHandle(offer)
                        )
                    )
                )
            }
        }
        configureLifecycleCallbacks()
    }

    private func configureLifecycleCallbacks() {
        unsafe callbacks.pointee.leave = { data, _ in
            RawDataDeviceOwner.withOwner(
                data,
                message: "wl_data_device leave fired without Swift state"
            ) { owner in
                owner.onEvent(.leave)
            }
        }
        unsafe callbacks.pointee.motion = { data, _, time, x, y in
            RawDataDeviceOwner.withOwner(
                data,
                message: "wl_data_device motion fired without Swift state"
            ) { owner in
                owner.onEvent(
                    .motion(
                        time: time,
                        x: WaylandFixed(rawValue: x),
                        y: WaylandFixed(rawValue: y)
                    )
                )
            }
        }
        unsafe callbacks.pointee.drop = { data, _ in
            RawDataDeviceOwner.withOwner(
                data,
                message: "wl_data_device drop fired without Swift state"
            ) { owner in
                owner.onEvent(.drop)
            }
        }
        unsafe callbacks.pointee.selection = { data, _, offer in
            RawDataDeviceOwner.withOwner(
                data,
                message: "wl_data_device selection fired without Swift state"
            ) { owner in
                owner.onEvent(.selection(unsafe RawDataOfferHandle(offer)))
            }
        }
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawDataDeviceOwner) -> Void
    ) {
        CListenerStorage<RawDataDeviceOwner, swl_data_device_listener_callbacks>
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
