import CWaylandProtocols
import Glibc

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

package struct RawDataDeviceEnter: Equatable {
    package let serial: UInt32
    package let surface: OpaquePointer?
    package let x: WaylandFixed
    package let y: WaylandFixed
    package let offer: OpaquePointer?
}

package enum RawDataDeviceEvent: Equatable {
    case dataOffer(OpaquePointer?)
    case enter(RawDataDeviceEnter)
    case leave
    case motion(time: UInt32, x: WaylandFixed, y: WaylandFixed)
    case drop
    case selection(OpaquePointer?)
}

private enum DataDeviceListenerInstallState {
    case idle
    case installed
}

package final class RawDataOfferOwner {
    private let onEvent: (RawDataOfferEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = DataDeviceListenerInstallState.idle
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_data_offer_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    private var callbacks: UnsafeMutablePointer<swl_data_offer_listener_callbacks> {
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

        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

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
        callbacks.pointee.offer = { data, _, mimeType in
            RawDataOfferOwner.withOwner(
                data,
                message: "wl_data_offer offer fired without Swift state"
            ) { owner in
                owner.onEvent(.offer(optionalString(from: mimeType)))
            }
        }
        callbacks.pointee.source_actions = { data, _, actions in
            RawDataOfferOwner.withOwner(
                data,
                message: "wl_data_offer source_actions fired without Swift state"
            ) { owner in
                owner.onEvent(.sourceActions(.init(rawValue: actions)))
            }
        }
        callbacks.pointee.action = { data, _, action in
            RawDataOfferOwner.withOwner(
                data,
                message: "wl_data_offer action fired without Swift state"
            ) { owner in
                owner.onEvent(.action(.init(rawValue: action)))
            }
        }
    }

    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawDataOfferOwner) -> Void
    ) {
        CListenerStorage<RawDataOfferOwner, swl_data_offer_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

package final class RawDataSourceOwner {
    private let onEvent: (RawDataSourceEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = DataDeviceListenerInstallState.idle
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_data_source_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    private var callbacks: UnsafeMutablePointer<swl_data_source_listener_callbacks> {
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

        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

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
        callbacks.pointee.target = { data, _, mimeType in
            RawDataSourceOwner.withOwner(
                data,
                message: "wl_data_source target fired without Swift state"
            ) { owner in
                owner.onEvent(.target(optionalString(from: mimeType)))
            }
        }
        callbacks.pointee.send = { data, _, mimeType, fd in
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
        callbacks.pointee.cancelled = { data, _ in
            RawDataSourceOwner.withOwner(
                data,
                message: "wl_data_source cancelled fired without Swift state"
            ) { owner in
                owner.onEvent(.cancelled)
            }
        }
        callbacks.pointee.dnd_drop_performed = { data, _ in
            RawDataSourceOwner.withOwner(
                data,
                message: "wl_data_source dnd_drop_performed fired without Swift state"
            ) { owner in
                owner.onEvent(.dndDropPerformed)
            }
        }
        callbacks.pointee.dnd_finished = { data, _ in
            RawDataSourceOwner.withOwner(
                data,
                message: "wl_data_source dnd_finished fired without Swift state"
            ) { owner in
                owner.onEvent(.dndFinished)
            }
        }
        callbacks.pointee.action = { data, _, action in
            RawDataSourceOwner.withOwner(
                data,
                message: "wl_data_source action fired without Swift state"
            ) { owner in
                owner.onEvent(.action(.init(rawValue: action)))
            }
        }
    }

    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawDataSourceOwner) -> Void
    ) {
        CListenerStorage<RawDataSourceOwner, swl_data_source_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}

package final class RawDataDeviceOwner {
    private let onEvent: (RawDataDeviceEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = DataDeviceListenerInstallState.idle
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_data_device_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    private var callbacks: UnsafeMutablePointer<swl_data_device_listener_callbacks> {
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

        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

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
        callbacks.pointee.data_offer = { data, _, offer in
            RawDataDeviceOwner.withOwner(
                data,
                message: "wl_data_device data_offer fired without Swift state"
            ) { owner in
                owner.onEvent(.dataOffer(offer))
            }
        }
        callbacks.pointee.enter = { data, _, serial, surface, x, y, offer in
            RawDataDeviceOwner.withOwner(
                data,
                message: "wl_data_device enter fired without Swift state"
            ) { owner in
                owner.onEvent(
                    .enter(
                        RawDataDeviceEnter(
                            serial: serial,
                            surface: surface,
                            x: WaylandFixed(rawValue: x),
                            y: WaylandFixed(rawValue: y),
                            offer: offer
                        )
                    )
                )
            }
        }
        configureLifecycleCallbacks()
    }

    private func configureLifecycleCallbacks() {
        callbacks.pointee.leave = { data, _ in
            RawDataDeviceOwner.withOwner(
                data,
                message: "wl_data_device leave fired without Swift state"
            ) { owner in
                owner.onEvent(.leave)
            }
        }
        callbacks.pointee.motion = { data, _, time, x, y in
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
        callbacks.pointee.drop = { data, _ in
            RawDataDeviceOwner.withOwner(
                data,
                message: "wl_data_device drop fired without Swift state"
            ) { owner in
                owner.onEvent(.drop)
            }
        }
        callbacks.pointee.selection = { data, _, offer in
            RawDataDeviceOwner.withOwner(
                data,
                message: "wl_data_device selection fired without Swift state"
            ) { owner in
                owner.onEvent(.selection(offer))
            }
        }
    }

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

private func optionalString(from cString: UnsafePointer<CChar>?) -> String? {
    cString.map { String(cString: $0) }
}
