import CWaylandProtocols

@safe
package final class RawPointerGestures {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer gesturesPointer: OpaquePointer,
        version gesturesVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        version = gesturesVersion
        proxyAdoption = adoptionContext
        proxy = try RawOwnedProxy(
            adopting: gesturesPointer,
            interface: "zwp_pointer_gestures_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zwp_pointer_gestures_v1_destroy
        )
    }

    package func swipeGesture(for seat: RawSeat) throws -> RawPointerSwipeGesture {
        guard let pointerDevice = unsafe seat.pointerDevicePointer else {
            throw RuntimeError.bindFailed("wl_pointer")
        }
        guard let gesture = unsafe swl_zwp_pointer_gestures_v1_get_swipe_gesture(
            pointer,
            pointerDevice
        ) else {
            throw RuntimeError.bindFailed("zwp_pointer_gesture_swipe_v1")
        }

        let adoptedGesture = try unsafe proxyAdoption.adoptOrDestroy(
            gesture,
            interface: "zwp_pointer_gesture_swipe_v1",
            destroy: unsafe swl_zwp_pointer_gesture_swipe_v1_destroy
        )
        return RawPointerSwipeGesture(pointer: adoptedGesture)
    }

    package func pinchGesture(for seat: RawSeat) throws -> RawPointerPinchGesture {
        guard let pointerDevice = unsafe seat.pointerDevicePointer else {
            throw RuntimeError.bindFailed("wl_pointer")
        }
        guard let gesture = unsafe swl_zwp_pointer_gestures_v1_get_pinch_gesture(
            pointer,
            pointerDevice
        ) else {
            throw RuntimeError.bindFailed("zwp_pointer_gesture_pinch_v1")
        }

        let adoptedGesture = try unsafe proxyAdoption.adoptOrDestroy(
            gesture,
            interface: "zwp_pointer_gesture_pinch_v1",
            destroy: unsafe swl_zwp_pointer_gesture_pinch_v1_destroy
        )
        return RawPointerPinchGesture(pointer: adoptedGesture)
    }

    package func holdGesture(for seat: RawSeat) throws -> RawPointerHoldGesture {
        guard version >= RawVersion(3) else {
            throw RuntimeError.unsupportedProtocolVersion(
                interface: "zwp_pointer_gestures_v1",
                minimum: RawVersion(3),
                actual: version
            )
        }
        guard let pointerDevice = unsafe seat.pointerDevicePointer else {
            throw RuntimeError.bindFailed("wl_pointer")
        }
        guard let gesture = unsafe swl_zwp_pointer_gestures_v1_get_hold_gesture(
            pointer,
            pointerDevice
        ) else {
            throw RuntimeError.bindFailed("zwp_pointer_gesture_hold_v1")
        }

        let adoptedGesture = try unsafe proxyAdoption.adoptOrDestroy(
            gesture,
            interface: "zwp_pointer_gesture_hold_v1",
            destroy: unsafe swl_zwp_pointer_gesture_hold_v1_destroy
        )
        return RawPointerHoldGesture(pointer: adoptedGesture)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawPointerSwipeGesture {
    private var proxy: RawOwnedProxy

    @safe
    init(pointer gesturePointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: gesturePointer,
            destroy: unsafe swl_zwp_pointer_gesture_swipe_v1_destroy
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
package final class RawPointerPinchGesture {
    private var proxy: RawOwnedProxy

    @safe
    init(pointer gesturePointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: gesturePointer,
            destroy: unsafe swl_zwp_pointer_gesture_pinch_v1_destroy
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
package final class RawPointerHoldGesture {
    private var proxy: RawOwnedProxy

    @safe
    init(pointer gesturePointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: gesturePointer,
            destroy: unsafe swl_zwp_pointer_gesture_hold_v1_destroy
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
package final class RawKeyboardShortcutsInhibitManager {
    package let version: RawVersion

    private let proxyAdoption: RawProxyAdoptionContext
    private var proxy: RawOwnedProxy

    @safe private var pointer: OpaquePointer { proxy.pointer }

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
            interface: "zwp_keyboard_shortcuts_inhibit_manager_v1",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_zwp_keyboard_shortcuts_inhibit_manager_v1_destroy
        )
    }

    package func inhibitShortcuts(
        surface: RawSurface,
        seat: RawSeat
    ) throws -> RawKeyboardShortcutsInhibitor {
        guard let inhibitor = unsafe swl_zwp_keyboard_shortcuts_inhibit_manager_v1_inhibit_shortcuts(
            pointer,
            surface.pointer,
            seat.pointer
        ) else {
            throw RuntimeError.bindFailed("zwp_keyboard_shortcuts_inhibitor_v1")
        }

        let adoptedInhibitor = try unsafe proxyAdoption.adoptOrDestroy(
            inhibitor,
            interface: "zwp_keyboard_shortcuts_inhibitor_v1",
            destroy: unsafe swl_zwp_keyboard_shortcuts_inhibitor_v1_destroy
        )
        return RawKeyboardShortcutsInhibitor(pointer: adoptedInhibitor)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawKeyboardShortcutsInhibitor {
    private var proxy: RawOwnedProxy

    @safe
    init(pointer inhibitorPointer: OpaquePointer) {
        proxy = RawOwnedProxy(
            pointer: inhibitorPointer,
            destroy: unsafe swl_zwp_keyboard_shortcuts_inhibitor_v1_destroy
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
