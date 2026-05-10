import CWaylandProtocols

@safe
package struct RawSeatProxyOperations {
    @safe package var bindSeat: (OpaquePointer, UInt32, UInt32) -> OpaquePointer?
    @safe package var addSeatListener:
        (OpaquePointer, UnsafePointer<swl_seat_listener_callbacks>) -> Int32
    @safe package var addPointerListener:
        (OpaquePointer, UnsafePointer<swl_pointer_listener_callbacks>) -> Int32
    @safe package var addKeyboardListener:
        (OpaquePointer, UnsafePointer<swl_keyboard_listener_callbacks>) -> Int32
    @safe package var addTouchListener:
        (OpaquePointer, UnsafePointer<swl_touch_listener_callbacks>) -> Int32
    @safe package var getPointer: (OpaquePointer) -> OpaquePointer?
    @safe package var getKeyboard: (OpaquePointer) -> OpaquePointer?
    @safe package var getTouch: (OpaquePointer) -> OpaquePointer?
    @safe package var setPointerCursor:
        (OpaquePointer, UInt32, OpaquePointer?, Int32, Int32) -> Void
    @safe package var proxyVersion: (OpaquePointer) -> RawVersion
    @safe package var proxyObjectID: (OpaquePointer?) -> RawObjectID?
    @safe package var releasePointer: (OpaquePointer) -> Void
    @safe package var releaseKeyboard: (OpaquePointer) -> Void
    @safe package var releaseTouch: (OpaquePointer) -> Void
    @safe package var releaseSeat: (OpaquePointer) -> Void

    package static var live: RawSeatProxyOperations {
        unsafe RawSeatProxyOperations(
            bindSeat: { registry, name, version in
                unsafe swl_registry_bind_wl_seat(registry, name, version)
            },
            addSeatListener: { seat, callbacks in
                unsafe swl_seat_add_listener(seat, callbacks)
            },
            addPointerListener: { pointer, callbacks in
                unsafe swl_pointer_add_listener(pointer, callbacks)
            },
            addKeyboardListener: { keyboard, callbacks in
                unsafe swl_keyboard_add_listener(keyboard, callbacks)
            },
            addTouchListener: { touch, callbacks in
                unsafe swl_touch_add_listener(touch, callbacks)
            },
            getPointer: { seat in
                unsafe swl_seat_get_pointer(seat)
            },
            getKeyboard: { seat in
                unsafe swl_seat_get_keyboard(seat)
            },
            getTouch: { seat in
                unsafe swl_seat_get_touch(seat)
            },
            setPointerCursor: { pointer, serial, surface, hotspotX, hotspotY in
                unsafe swl_pointer_set_cursor(pointer, serial, surface, hotspotX, hotspotY)
            },
            proxyVersion: { proxy in
                unsafe RawVersion(swl_proxy_get_version(UnsafeMutableRawPointer(proxy)))
            },
            proxyObjectID: { proxy in
                guard let proxy = unsafe proxy else { return nil }

                return unsafe RawObjectID(
                    swl_proxy_get_id(UnsafeMutableRawPointer(proxy))
                )
            },
            releasePointer: { pointer in
                unsafe swl_pointer_release(pointer)
            },
            releaseKeyboard: { keyboard in
                unsafe swl_keyboard_release(keyboard)
            },
            releaseTouch: { touch in
                unsafe swl_touch_release(touch)
            },
            releaseSeat: { seat in
                unsafe swl_seat_release(seat)
            }
        )
    }

    #if DEBUG
        package static var testingNoop: RawSeatProxyOperations {
            unsafe RawSeatProxyOperations(
                bindSeat: { _, _, _ in nil },
                addSeatListener: { _, _ in 0 },
                addPointerListener: { _, _ in 0 },
                addKeyboardListener: { _, _ in 0 },
                addTouchListener: { _, _ in 0 },
                getPointer: { _ in nil },
                getKeyboard: { _ in nil },
                getTouch: { _ in nil },
                setPointerCursor: { _, _, _, _, _ in return },
                proxyVersion: { _ in RawVersion(10) },
                proxyObjectID: { proxy in
                    guard let proxy = unsafe proxy else { return nil }

                    return unsafe RawObjectID(
                        UInt32(truncatingIfNeeded: UInt(bitPattern: UnsafeRawPointer(proxy)))
                    )
                },
                releasePointer: { _ in return },
                releaseKeyboard: { _ in return },
                releaseTouch: { _ in return },
                releaseSeat: { _ in return }
            )
        }
    #endif
}
