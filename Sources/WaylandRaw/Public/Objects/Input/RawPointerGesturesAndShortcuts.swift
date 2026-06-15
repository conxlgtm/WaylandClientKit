import CWaylandProtocols
import Glibc

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

    package func swipeGesture(
        for seat: RawSeat,
        eventSink: RawInputEventSink,
        invariantFailureSink: RawInvariantFailureSink?
    ) throws -> RawPointerSwipeGesture {
        guard let pointerDevice = unsafe seat.pointerDevicePointer else {
            throw RuntimeError.bindFailed("wl_pointer")
        }
        guard
            let gesture = unsafe swl_zwp_pointer_gestures_v1_get_swipe_gesture(
                pointer,
                pointerDevice
            )
        else {
            throw RuntimeError.bindFailed("zwp_pointer_gesture_swipe_v1")
        }

        let adoptedGesture = try unsafe proxyAdoption.adoptOrDestroy(
            gesture,
            interface: "zwp_pointer_gesture_swipe_v1",
            destroy: unsafe swl_zwp_pointer_gesture_swipe_v1_destroy
        )
        let owner = RawPointerSwipeGestureOwner(
            seatID: seat.id,
            deviceID: seat.pointerDeviceID,
            eventSink: eventSink,
            invariantFailureSink: invariantFailureSink
        )
        do {
            try unsafe owner.install(on: adoptedGesture)
        } catch {
            owner.cancel()
            unsafe swl_zwp_pointer_gesture_swipe_v1_destroy(adoptedGesture)
            throw error
        }
        return RawPointerSwipeGesture(pointer: adoptedGesture, listenerOwner: owner)
    }

    package func pinchGesture(
        for seat: RawSeat,
        eventSink: RawInputEventSink,
        invariantFailureSink: RawInvariantFailureSink?
    ) throws -> RawPointerPinchGesture {
        guard let pointerDevice = unsafe seat.pointerDevicePointer else {
            throw RuntimeError.bindFailed("wl_pointer")
        }
        guard
            let gesture = unsafe swl_zwp_pointer_gestures_v1_get_pinch_gesture(
                pointer,
                pointerDevice
            )
        else {
            throw RuntimeError.bindFailed("zwp_pointer_gesture_pinch_v1")
        }

        let adoptedGesture = try unsafe proxyAdoption.adoptOrDestroy(
            gesture,
            interface: "zwp_pointer_gesture_pinch_v1",
            destroy: unsafe swl_zwp_pointer_gesture_pinch_v1_destroy
        )
        let owner = RawPointerPinchGestureOwner(
            seatID: seat.id,
            deviceID: seat.pointerDeviceID,
            eventSink: eventSink,
            invariantFailureSink: invariantFailureSink
        )
        do {
            try unsafe owner.install(on: adoptedGesture)
        } catch {
            owner.cancel()
            unsafe swl_zwp_pointer_gesture_pinch_v1_destroy(adoptedGesture)
            throw error
        }
        return RawPointerPinchGesture(pointer: adoptedGesture, listenerOwner: owner)
    }

    package func holdGesture(
        for seat: RawSeat,
        eventSink: RawInputEventSink,
        invariantFailureSink: RawInvariantFailureSink?
    ) throws -> RawPointerHoldGesture {
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
        guard
            let gesture = unsafe swl_zwp_pointer_gestures_v1_get_hold_gesture(
                pointer,
                pointerDevice
            )
        else {
            throw RuntimeError.bindFailed("zwp_pointer_gesture_hold_v1")
        }

        let adoptedGesture = try unsafe proxyAdoption.adoptOrDestroy(
            gesture,
            interface: "zwp_pointer_gesture_hold_v1",
            destroy: unsafe swl_zwp_pointer_gesture_hold_v1_destroy
        )
        let owner = RawPointerHoldGestureOwner(
            seatID: seat.id,
            deviceID: seat.pointerDeviceID,
            eventSink: eventSink,
            invariantFailureSink: invariantFailureSink
        )
        do {
            try unsafe owner.install(on: adoptedGesture)
        } catch {
            owner.cancel()
            unsafe swl_zwp_pointer_gesture_hold_v1_destroy(adoptedGesture)
            throw error
        }
        return RawPointerHoldGesture(pointer: adoptedGesture, listenerOwner: owner)
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
    private let listenerOwner: RawPointerSwipeGestureOwner?

    @safe
    package init(
        pointer gesturePointer: OpaquePointer,
        listenerOwner owner: RawPointerSwipeGestureOwner?
    ) {
        listenerOwner = owner
        proxy = RawOwnedProxy(
            pointer: gesturePointer,
            destroy: unsafe swl_zwp_pointer_gesture_swipe_v1_destroy
        )
    }

    package func destroy() {
        listenerOwner?.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawPointerPinchGesture {
    private var proxy: RawOwnedProxy
    private let listenerOwner: RawPointerPinchGestureOwner?

    @safe
    package init(
        pointer gesturePointer: OpaquePointer,
        listenerOwner owner: RawPointerPinchGestureOwner?
    ) {
        listenerOwner = owner
        proxy = RawOwnedProxy(
            pointer: gesturePointer,
            destroy: unsafe swl_zwp_pointer_gesture_pinch_v1_destroy
        )
    }

    package func destroy() {
        listenerOwner?.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawPointerHoldGesture {
    private var proxy: RawOwnedProxy
    private let listenerOwner: RawPointerHoldGestureOwner?

    @safe
    package init(
        pointer gesturePointer: OpaquePointer,
        listenerOwner owner: RawPointerHoldGestureOwner?
    ) {
        listenerOwner = owner
        proxy = RawOwnedProxy(
            pointer: gesturePointer,
            destroy: unsafe swl_zwp_pointer_gesture_hold_v1_destroy
        )
    }

    package func destroy() {
        listenerOwner?.cancel()
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
        seat: RawSeat,
        onEvent: @escaping (RawKeyboardShortcutsInhibitorEvent) -> Void =
            RawKeyboardShortcutsInhibitManager.ignoreKeyboardShortcutsInhibitorEvent
    ) throws -> RawKeyboardShortcutsInhibitor {
        guard
            let inhibitor = unsafe swl_zwp_keyboard_shortcuts_inhibit_manager_v1_inhibit_shortcuts(
                pointer,
                surface.pointer,
                seat.pointer
            )
        else {
            throw RuntimeError.bindFailed("zwp_keyboard_shortcuts_inhibitor_v1")
        }

        let adoptedInhibitor = try unsafe proxyAdoption.adoptOrDestroy(
            inhibitor,
            interface: "zwp_keyboard_shortcuts_inhibitor_v1",
            destroy: unsafe swl_zwp_keyboard_shortcuts_inhibitor_v1_destroy
        )
        let owner = RawKeyboardShortcutsInhibitorOwner(
            onEvent: onEvent,
            invariantFailureSink: proxyAdoption.invariantFailureSink
        )
        try unsafe owner.install(on: adoptedInhibitor)
        return RawKeyboardShortcutsInhibitor(
            pointer: adoptedInhibitor,
            listenerOwner: owner
        )
    }

    package func destroy() {
        proxy.destroy()
    }

    private static func ignoreKeyboardShortcutsInhibitorEvent(
        _ event: RawKeyboardShortcutsInhibitorEvent
    ) {
        _ = event
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawKeyboardShortcutsInhibitor {
    private let listenerOwner: RawKeyboardShortcutsInhibitorOwner?
    private var proxy: RawOwnedProxy

    @safe
    package init(
        pointer inhibitorPointer: OpaquePointer,
        listenerOwner owner: RawKeyboardShortcutsInhibitorOwner?,
        destroy destroyProxy: @escaping (OpaquePointer) -> Void =
            unsafe swl_zwp_keyboard_shortcuts_inhibitor_v1_destroy
    ) {
        listenerOwner = owner
        proxy = RawOwnedProxy(
            pointer: inhibitorPointer,
            destroy: destroyProxy
        )
    }

    package func destroy() {
        listenerOwner?.cancel()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
