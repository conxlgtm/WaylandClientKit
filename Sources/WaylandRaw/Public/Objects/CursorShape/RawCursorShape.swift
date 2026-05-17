import CWaylandProtocols

package struct RawCursorShapeName: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue shapeRawValue: UInt32) {
        rawValue = shapeRawValue
    }

    package static let `default` = Self(rawValue: 1)
    package static let pointer = Self(rawValue: 4)
    package static let crosshair = Self(rawValue: 8)
    package static let text = Self(rawValue: 9)
    package static let ewResize = Self(rawValue: 26)
    package static let nsResize = Self(rawValue: 27)
}

@safe
package final class RawCursorShapeManager {
    package let version: RawVersion
    private var proxy: RawOwnedProxy
    private let proxyAdoption: RawProxyAdoptionContext

    @safe var pointer: OpaquePointer {
        proxy.pointer
    }

    @safe
    init(
        pointer managerPointer: OpaquePointer,
        version managerVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = managerVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "wp_cursor_shape_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_wp_cursor_shape_manager_v1_destroy
        )
    }

    package func cursorShapeDevice(forPointer pointerDevice: OpaquePointer) throws
        -> RawCursorShapeDevice
    {
        guard
            let devicePointer = unsafe swl_wp_cursor_shape_manager_v1_get_pointer(
                pointer,
                pointerDevice
            )
        else {
            throw RuntimeError.bindFailed("wp_cursor_shape_device_v1")
        }

        let adoptedDevice = try unsafe proxyAdoption.adoptOrDestroy(
            devicePointer,
            interface: "wp_cursor_shape_device_v1",
            destroy: unsafe swl_wp_cursor_shape_device_v1_destroy
        )
        return RawCursorShapeDevice(
            pointer: adoptedDevice,
            version: version,
            destroy: unsafe swl_wp_cursor_shape_device_v1_destroy
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawCursorShapeDevice {
    package let version: RawVersion
    private var proxy: RawOwnedProxy

    @safe var pointer: OpaquePointer {
        proxy.pointer
    }

    @safe
    init(
        pointer devicePointer: OpaquePointer,
        version deviceVersion: RawVersion,
        destroy destroyDevice: @escaping (OpaquePointer) -> Void
    ) {
        version = deviceVersion
        proxy = RawOwnedProxy(pointer: devicePointer, destroy: destroyDevice)
    }

    package func setShape(serial: UInt32, shape: RawCursorShapeName) {
        unsafe swl_wp_cursor_shape_device_v1_set_shape(
            pointer,
            serial,
            shape.rawValue
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
