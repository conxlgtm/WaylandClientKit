import CWaylandProtocols
import Glibc

package final class RawPrimarySelectionDeviceManager {
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
                interface: "zwp_primary_selection_device_manager_v1"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_primary_selection_device_manager_destroy
            )
        } catch {
            unsafe swl_primary_selection_device_manager_destroy(managerPointer)
            throw error
        }
        version = managerVersion
        proxyAdoption = adoptionContext
    }

    package func createSource() throws -> RawPrimarySelectionSource {
        guard let source = unsafe swl_primary_selection_device_manager_create_source(pointer) else {
            throw RuntimeError.bindFailed("zwp_primary_selection_source_v1")
        }

        return try .init(pointer: source, version: version, proxyAdoption: proxyAdoption)
    }

    package func getDevice(for seat: RawSeat) throws -> RawPrimarySelectionDevice {
        guard
            let device = unsafe swl_primary_selection_device_manager_get_device(
                pointer,
                seat.pointer
            )
        else {
            throw RuntimeError.bindFailed("zwp_primary_selection_device_v1")
        }

        return try .init(pointer: device, version: version, proxyAdoption: proxyAdoption)
    }

    package func adoptOffer(
        _ offerHandle: RawPrimarySelectionOfferHandle
    ) throws -> RawPrimarySelectionOffer {
        guard let offerPointer = unsafe offerHandle.pointer else {
            throw RuntimeError.bindFailed("zwp_primary_selection_offer_v1")
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

package final class RawPrimarySelectionOffer {
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
                interface: "zwp_primary_selection_offer_v1"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_primary_selection_offer_destroy
            )
        } catch {
            unsafe swl_primary_selection_offer_destroy(offerPointer)
            throw error
        }
        version = offerVersion
    }

    package func receive(mimeType: String, fd: Int32) {
        mimeType.withCString { mimeTypePointer in
            unsafe swl_primary_selection_offer_receive(pointer, mimeTypePointer, fd)
        }
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

package final class RawPrimarySelectionSource {
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
                interface: "zwp_primary_selection_source_v1"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_primary_selection_source_destroy
            )
        } catch {
            unsafe swl_primary_selection_source_destroy(sourcePointer)
            throw error
        }
        version = sourceVersion
    }

    package func offer(mimeType: String) {
        mimeType.withCString { mimeTypePointer in
            unsafe swl_primary_selection_source_offer(pointer, mimeTypePointer)
        }
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

package final class RawPrimarySelectionDevice {
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
                interface: "zwp_primary_selection_device_v1"
            )
            proxy = RawOwnedProxy(
                pointer: adoptedPointer,
                destroy: unsafe swl_primary_selection_device_destroy
            )
        } catch {
            unsafe swl_primary_selection_device_destroy(devicePointer)
            throw error
        }
        version = deviceVersion
    }

    package func setSelection(source: RawPrimarySelectionSource?, serial: UInt32) {
        unsafe swl_primary_selection_device_set_selection(
            pointer,
            source?.pointer,
            serial
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
