import CWaylandProtocols
import Glibc

@safe
package final class RawPointerSwipeGestureOwner {
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

        installBeginCallback()
        installUpdateCallback()
        installEndCallback()
    }

    private func installBeginCallback() {
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
    }

    private func installUpdateCallback() {
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
    }

    private func installEndCallback() {
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
package final class RawPointerPinchGestureOwner {
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

        installBeginCallback()
        installUpdateCallback()
        installEndCallback()
    }

    private func installBeginCallback() {
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
    }

    private func installUpdateCallback() {
        unsafe callbacks.pointee.update = { data, _, time, dx, dy, scale, rotation in
            RawPointerPinchGestureOwner.withOwner(
                data,
                message: "zwp_pointer_gesture_pinch_v1 update fired without Swift state"
            ) { owner in
                owner.append(
                    .gesture(
                        .pinch(
                            .update(
                                RawPointerPinchGestureUpdate(
                                    time: time,
                                    dx: WaylandFixed(rawValue: dx),
                                    dy: WaylandFixed(rawValue: dy),
                                    scale: WaylandFixed(rawValue: scale),
                                    rotation: WaylandFixed(rawValue: rotation)
                                )
                            )
                        )
                    )
                )
            }
        }
    }

    private func installEndCallback() {
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
package final class RawPointerHoldGestureOwner {
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
