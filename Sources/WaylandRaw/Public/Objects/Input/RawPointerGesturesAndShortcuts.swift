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
    fileprivate init(
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
    fileprivate init(
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
    fileprivate init(
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
private final class RawPointerSwipeGestureOwner {
    private let seatID: RawSeatID
    private let deviceID: RawInputDeviceID?
    private let eventSink: RawInputEventSink
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_pointer_gesture_swipe_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_zwp_pointer_gesture_swipe_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        seatID gestureSeatID: RawSeatID,
        deviceID gestureDeviceID: RawInputDeviceID?,
        eventSink gestureEventSink: RawInputEventSink,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) {
        seatID = gestureSeatID
        deviceID = gestureDeviceID
        eventSink = gestureEventSink
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.begin = { data, _, serial, time, surface, fingers in
            RawPointerSwipeGestureOwner.withOwner(
                data,
                message: "zwp_pointer_gesture_swipe_v1 begin fired without Swift state"
            ) { owner in
                owner.append(
                    .gesture(
                        .swipe(
                            .begin(
                                serial: serial,
                                time: time,
                                surfaceID: unsafe RawSeatProxyOperations.live.proxyObjectID(
                                    surface
                                ),
                                fingers: fingers
                            )
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.update = { data, _, time, dx, dy in
            RawPointerSwipeGestureOwner.withOwner(
                data,
                message: "zwp_pointer_gesture_swipe_v1 update fired without Swift state"
            ) { owner in
                owner.append(
                    .gesture(
                        .swipe(
                            .update(
                                time: time,
                                dx: WaylandFixed(rawValue: dx),
                                dy: WaylandFixed(rawValue: dy)
                            )
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.end = { data, _, serial, time, cancelled in
            RawPointerSwipeGestureOwner.withOwner(
                data,
                message: "zwp_pointer_gesture_swipe_v1 end fired without Swift state"
            ) { owner in
                owner.append(
                    .gesture(
                        .swipe(
                            .end(
                                serial: serial,
                                time: time,
                                cancelled: cancelled != 0
                            )
                        )
                    )
                )
            }
        }
    }

    func install(on gesture: OpaquePointer) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwp_pointer_gesture_swipe_v1_add_listener(
            gesture,
            callbacks
        )
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("zwp_pointer_gesture_swipe_v1")
            )
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func append(_ event: RawPointerEvent) {
        guard !isCanceled else { return }

        eventSink.append(rawDraft(kind: .pointer(event)))
    }

    private func rawDraft(kind: RawInputEventKind) -> RawInputEventDraft {
        if let deviceID {
            RawInputEventDraft(deviceID: deviceID, kind: kind)
        } else {
            RawInputEventDraft(seatID: seatID, kind: kind)
        }
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawPointerSwipeGestureOwner) -> Void
    ) {
        CListenerStorage<
            RawPointerSwipeGestureOwner,
            swl_zwp_pointer_gesture_swipe_v1_listener_callbacks
        >.withOwner(from: data, message: message(), body)
    }
}

@safe
private final class RawPointerPinchGestureOwner {
    private let seatID: RawSeatID
    private let deviceID: RawInputDeviceID?
    private let eventSink: RawInputEventSink
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_pointer_gesture_pinch_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_zwp_pointer_gesture_pinch_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        seatID gestureSeatID: RawSeatID,
        deviceID gestureDeviceID: RawInputDeviceID?,
        eventSink gestureEventSink: RawInputEventSink,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) {
        seatID = gestureSeatID
        deviceID = gestureDeviceID
        eventSink = gestureEventSink
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.begin = { data, _, serial, time, surface, fingers in
            RawPointerPinchGestureOwner.withOwner(
                data,
                message: "zwp_pointer_gesture_pinch_v1 begin fired without Swift state"
            ) { owner in
                owner.append(
                    .gesture(
                        .pinch(
                            .begin(
                                serial: serial,
                                time: time,
                                surfaceID: unsafe RawSeatProxyOperations.live.proxyObjectID(
                                    surface
                                ),
                                fingers: fingers
                            )
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.update = { data, _, time, dx, dy, scale, rotation in
            RawPointerPinchGestureOwner.withOwner(
                data,
                message: "zwp_pointer_gesture_pinch_v1 update fired without Swift state"
            ) { owner in
                owner.append(
                    .gesture(
                        .pinch(
                            .update(
                                time: time,
                                dx: WaylandFixed(rawValue: dx),
                                dy: WaylandFixed(rawValue: dy),
                                scale: WaylandFixed(rawValue: scale),
                                rotation: WaylandFixed(rawValue: rotation)
                            )
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.end = { data, _, serial, time, cancelled in
            RawPointerPinchGestureOwner.withOwner(
                data,
                message: "zwp_pointer_gesture_pinch_v1 end fired without Swift state"
            ) { owner in
                owner.append(
                    .gesture(
                        .pinch(
                            .end(
                                serial: serial,
                                time: time,
                                cancelled: cancelled != 0
                            )
                        )
                    )
                )
            }
        }
    }

    func install(on gesture: OpaquePointer) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwp_pointer_gesture_pinch_v1_add_listener(
            gesture,
            callbacks
        )
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("zwp_pointer_gesture_pinch_v1")
            )
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func append(_ event: RawPointerEvent) {
        guard !isCanceled else { return }

        eventSink.append(rawDraft(kind: .pointer(event)))
    }

    private func rawDraft(kind: RawInputEventKind) -> RawInputEventDraft {
        if let deviceID {
            RawInputEventDraft(deviceID: deviceID, kind: kind)
        } else {
            RawInputEventDraft(seatID: seatID, kind: kind)
        }
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawPointerPinchGestureOwner) -> Void
    ) {
        CListenerStorage<
            RawPointerPinchGestureOwner,
            swl_zwp_pointer_gesture_pinch_v1_listener_callbacks
        >.withOwner(from: data, message: message(), body)
    }
}

@safe
private final class RawPointerHoldGestureOwner {
    private let seatID: RawSeatID
    private let deviceID: RawInputDeviceID?
    private let eventSink: RawInputEventSink
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_pointer_gesture_hold_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<swl_zwp_pointer_gesture_hold_v1_listener_callbacks>
    {
        listenerStorage.callbacks
    }

    init(
        seatID gestureSeatID: RawSeatID,
        deviceID gestureDeviceID: RawInputDeviceID?,
        eventSink gestureEventSink: RawInputEventSink,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) {
        seatID = gestureSeatID
        deviceID = gestureDeviceID
        eventSink = gestureEventSink
        invariantFailureSink = failureSink

        unsafe callbacks.pointee.begin = { data, _, serial, time, surface, fingers in
            RawPointerHoldGestureOwner.withOwner(
                data,
                message: "zwp_pointer_gesture_hold_v1 begin fired without Swift state"
            ) { owner in
                owner.append(
                    .gesture(
                        .hold(
                            .begin(
                                serial: serial,
                                time: time,
                                surfaceID: unsafe RawSeatProxyOperations.live.proxyObjectID(
                                    surface
                                ),
                                fingers: fingers
                            )
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.end = { data, _, serial, time, cancelled in
            RawPointerHoldGestureOwner.withOwner(
                data,
                message: "zwp_pointer_gesture_hold_v1 end fired without Swift state"
            ) { owner in
                owner.append(
                    .gesture(
                        .hold(
                            .end(
                                serial: serial,
                                time: time,
                                cancelled: cancelled != 0
                            )
                        )
                    )
                )
            }
        }
    }

    func install(on gesture: OpaquePointer) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwp_pointer_gesture_hold_v1_add_listener(
            gesture,
            callbacks
        )
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("zwp_pointer_gesture_hold_v1")
            )
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func append(_ event: RawPointerEvent) {
        guard !isCanceled else { return }

        eventSink.append(rawDraft(kind: .pointer(event)))
    }

    private func rawDraft(kind: RawInputEventKind) -> RawInputEventDraft {
        if let deviceID {
            RawInputEventDraft(deviceID: deviceID, kind: kind)
        } else {
            RawInputEventDraft(seatID: seatID, kind: kind)
        }
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawPointerHoldGestureOwner) -> Void
    ) {
        CListenerStorage<
            RawPointerHoldGestureOwner,
            swl_zwp_pointer_gesture_hold_v1_listener_callbacks
        >.withOwner(from: data, message: message(), body)
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
