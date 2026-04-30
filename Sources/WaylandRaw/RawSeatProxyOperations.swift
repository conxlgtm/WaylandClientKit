import CWaylandProtocols

package struct RawSeatProxyOperations {
    package var bindSeat: (OpaquePointer, UInt32, UInt32) -> OpaquePointer?
    package var addSeatListener:
        (OpaquePointer, UnsafePointer<swl_seat_listener_callbacks>) -> Int32
    package var addPointerListener:
        (OpaquePointer, UnsafePointer<swl_pointer_listener_callbacks>) -> Int32
    package var addKeyboardListener:
        (OpaquePointer, UnsafePointer<swl_keyboard_listener_callbacks>) -> Int32
    package var addTouchListener:
        (OpaquePointer, UnsafePointer<swl_touch_listener_callbacks>) -> Int32
    package var getPointer: (OpaquePointer) -> OpaquePointer?
    package var getKeyboard: (OpaquePointer) -> OpaquePointer?
    package var getTouch: (OpaquePointer) -> OpaquePointer?
    package var setPointerCursor: (OpaquePointer, UInt32, OpaquePointer?, Int32, Int32) -> Void
    package var proxyVersion: (OpaquePointer) -> RawVersion
    package var proxyObjectID: (OpaquePointer?) -> RawObjectID?
    package var releasePointer: (OpaquePointer) -> Void
    package var releaseKeyboard: (OpaquePointer) -> Void
    package var releaseTouch: (OpaquePointer) -> Void
    package var releaseSeat: (OpaquePointer) -> Void

    package static var live: RawSeatProxyOperations {
        RawSeatProxyOperations(
            bindSeat: { registry, name, version in
                swl_registry_bind_wl_seat(registry, name, version)
            },
            addSeatListener: { seat, callbacks in
                swl_seat_add_listener(seat, callbacks)
            },
            addPointerListener: { pointer, callbacks in
                swl_pointer_add_listener(pointer, callbacks)
            },
            addKeyboardListener: { keyboard, callbacks in
                swl_keyboard_add_listener(keyboard, callbacks)
            },
            addTouchListener: { touch, callbacks in
                swl_touch_add_listener(touch, callbacks)
            },
            getPointer: { seat in
                swl_seat_get_pointer(seat)
            },
            getKeyboard: { seat in
                swl_seat_get_keyboard(seat)
            },
            getTouch: { seat in
                swl_seat_get_touch(seat)
            },
            setPointerCursor: { pointer, serial, surface, hotspotX, hotspotY in
                swl_pointer_set_cursor(pointer, serial, surface, hotspotX, hotspotY)
            },
            proxyVersion: { proxy in
                RawVersion(swl_proxy_get_version(UnsafeMutableRawPointer(proxy)))
            },
            proxyObjectID: { proxy in
                proxy.map { RawObjectID(swl_proxy_get_id(UnsafeMutableRawPointer($0))) }
            },
            releasePointer: { pointer in
                swl_pointer_release(pointer)
            },
            releaseKeyboard: { keyboard in
                swl_keyboard_release(keyboard)
            },
            releaseTouch: { touch in
                swl_touch_release(touch)
            },
            releaseSeat: { seat in
                swl_seat_release(seat)
            }
        )
    }
}
