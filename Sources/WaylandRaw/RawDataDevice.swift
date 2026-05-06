import CWaylandProtocols
import Glibc

package struct RawDataDeviceDNDAction: OptionSet, Sendable {
    package let rawValue: UInt32

    package init(rawValue actionRawValue: UInt32) {
        rawValue = actionRawValue
    }

    package static let none = Self(rawValue: swl_data_device_manager_dnd_action_none())
    package static let copy = Self(rawValue: swl_data_device_manager_dnd_action_copy())
    package static let move = Self(rawValue: swl_data_device_manager_dnd_action_move())
    package static let ask = Self(rawValue: swl_data_device_manager_dnd_action_ask())
}

package final class RawDataDeviceManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    private var pointer: OpaquePointer { proxy.pointer }

    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                managerPointer,
                interface: "wl_data_device_manager"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_data_device_manager_destroy
            )
        } catch {
            unsafe swl_data_device_manager_destroy(managerPointer)
            throw error
        }
        version = managerVersion
        proxyAdoption = adoptionContext
    }

    package func createDataSource() throws -> RawDataSource {
        guard let source = unsafe swl_data_device_manager_create_data_source(pointer) else {
            throw RuntimeError.bindFailed("wl_data_source")
        }

        return try .init(pointer: source, version: version, proxyAdoption: proxyAdoption)
    }

    package func getDataDevice(for seat: RawSeat) throws -> RawDataDevice {
        guard
            let device = unsafe swl_data_device_manager_get_data_device(pointer, seat.pointer)
        else {
            throw RuntimeError.bindFailed("wl_data_device")
        }

        return try .init(pointer: device, version: version, proxyAdoption: proxyAdoption)
    }

    package func adoptDataOffer(_ offerHandle: RawDataOfferHandle) throws -> RawDataOffer {
        guard let offerPointer = unsafe offerHandle.pointer else {
            throw RuntimeError.bindFailed("wl_data_offer")
        }

        return try unsafe .init(
            pointer: offerPointer,
            version: version,
            proxyAdoption: proxyAdoption
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

package final class RawDataOffer {
    package let version: RawVersion

    private var proxy: RawOwnedProxy

    var pointer: OpaquePointer { proxy.pointer }

    init(
        pointer offerPointer: OpaquePointer,
        version offerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                offerPointer,
                interface: "wl_data_offer"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_data_offer_destroy
            )
        } catch {
            unsafe swl_data_offer_destroy(offerPointer)
            throw error
        }
        version = offerVersion
    }

    package func accept(serial: UInt32, mimeType: String?) {
        withOptionalCString(mimeType) { mimeTypePointer in
            unsafe swl_data_offer_accept(pointer, serial, mimeTypePointer)
        }
    }

    package func receive(mimeType: String, fd: Int32) {
        mimeType.withCString { mimeTypePointer in
            unsafe swl_data_offer_receive(pointer, mimeTypePointer, fd)
        }
    }

    package func finish() {
        unsafe swl_data_offer_finish(pointer)
    }

    package func setActions(
        _ actions: RawDataDeviceDNDAction,
        preferredAction: RawDataDeviceDNDAction
    ) {
        unsafe swl_data_offer_set_actions(
            pointer,
            actions.rawValue,
            preferredAction.rawValue
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

package final class RawDataSource {
    package let version: RawVersion

    private var proxy: RawOwnedProxy

    var pointer: OpaquePointer { proxy.pointer }

    init(
        pointer sourcePointer: OpaquePointer,
        version sourceVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                sourcePointer,
                interface: "wl_data_source"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_data_source_destroy
            )
        } catch {
            unsafe swl_data_source_destroy(sourcePointer)
            throw error
        }
        version = sourceVersion
    }

    package func offer(mimeType: String) {
        mimeType.withCString { mimeTypePointer in
            unsafe swl_data_source_offer(pointer, mimeTypePointer)
        }
    }

    package func setActions(_ actions: RawDataDeviceDNDAction) {
        unsafe swl_data_source_set_actions(pointer, actions.rawValue)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

package final class RawDataDevice {
    package let version: RawVersion

    private var proxy: RawOwnedProxy

    var pointer: OpaquePointer { proxy.pointer }

    init(
        pointer devicePointer: OpaquePointer,
        version deviceVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        do {
            let adoptedPointer = try adoptionContext.adopt(
                devicePointer,
                interface: "wl_data_device"
            )
            let destroyDevice: (OpaquePointer?) -> Void
            if deviceVersion >= RawVersion(2) {
                destroyDevice = unsafe swl_data_device_release
            } else {
                destroyDevice = unsafe swl_data_device_destroy
            }
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: destroyDevice
            )
        } catch {
            if deviceVersion >= RawVersion(2) {
                unsafe swl_data_device_release(devicePointer)
            } else {
                unsafe swl_data_device_destroy(devicePointer)
            }
            throw error
        }
        version = deviceVersion
    }

    package func setSelection(source: RawDataSource?, serial: UInt32) {
        unsafe swl_data_device_set_selection(pointer, source?.pointer, serial)
    }

    package func startDrag(
        source: RawDataSource?,
        origin: RawSurface,
        icon: RawSurface?,
        serial: UInt32
    ) {
        unsafe swl_data_device_start_drag(
            pointer,
            source?.pointer,
            origin.pointer,
            icon?.pointer,
            serial
        )
    }

    package func release() {
        proxy.destroy()
    }

    deinit {
        release()
    }
}

private func withOptionalCString<Result>(
    _ string: String?,
    _ body: (UnsafePointer<CChar>?) -> Result
) -> Result {
    guard let string else {
        return body(nil)
    }

    return string.withCString(body)
}
