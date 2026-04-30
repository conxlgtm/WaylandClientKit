import CWaylandProtocols

final class TouchListenerOwner {
    private let deviceID: RawInputDeviceID
    private let eventSink: RawInputEventSink
    private let operations: RawSeatProxyOperations
    private let isCurrentDevice: (RawInputDeviceID) -> Bool
    private var isCanceled = false
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_touch_listener_callbacks()
    )

    private var callbacks: UnsafeMutablePointer<swl_touch_listener_callbacks> {
        listenerStorage.callbacks
    }

    // swiftlint:disable:next function_body_length
    init(
        deviceID touchDeviceID: RawInputDeviceID,
        eventSink touchEventSink: RawInputEventSink,
        operations touchOperations: RawSeatProxyOperations,
        isCurrentDevice isTouchCurrent: @escaping (RawInputDeviceID) -> Bool
    ) {
        deviceID = touchDeviceID
        eventSink = touchEventSink
        operations = touchOperations
        isCurrentDevice = isTouchCurrent

        callbacks.pointee.down = { data, _, serial, time, surface, id, x, y in
            let owner = TouchListenerOwner.requireOwner(
                data,
                message: "wl_touch down fired without Swift state"
            )
            owner.append(
                .down(
                    RawTouchDown(
                        serial: serial,
                        time: time,
                        surfaceID: owner.operations.proxyObjectID(surface),
                        id: id,
                        x: WaylandFixed(rawValue: x),
                        y: WaylandFixed(rawValue: y)
                    )
                )
            )
        }

        callbacks.pointee.up = { data, _, serial, time, id in
            let owner = TouchListenerOwner.requireOwner(
                data,
                message: "wl_touch up fired without Swift state"
            )
            owner.append(.up(RawTouchUp(serial: serial, time: time, id: id)))
        }

        callbacks.pointee.motion = { data, _, time, id, x, y in
            let owner = TouchListenerOwner.requireOwner(
                data,
                message: "wl_touch motion fired without Swift state"
            )
            owner.append(
                .motion(
                    RawTouchMotion(
                        time: time,
                        id: id,
                        x: WaylandFixed(rawValue: x),
                        y: WaylandFixed(rawValue: y)
                    )
                )
            )
        }

        callbacks.pointee.frame = { data, _ in
            let owner = TouchListenerOwner.requireOwner(
                data,
                message: "wl_touch frame fired without Swift state"
            )
            owner.append(.frame)
        }

        callbacks.pointee.cancel = { data, _ in
            let owner = TouchListenerOwner.requireOwner(
                data,
                message: "wl_touch cancel fired without Swift state"
            )
            owner.append(.cancel)
        }

        callbacks.pointee.shape = { data, _, id, major, minor in
            let owner = TouchListenerOwner.requireOwner(
                data,
                message: "wl_touch shape fired without Swift state"
            )
            owner.append(
                .shape(
                    RawTouchShape(
                        id: id,
                        major: WaylandFixed(rawValue: major),
                        minor: WaylandFixed(rawValue: minor)
                    )
                )
            )
        }

        callbacks.pointee.orientation = { data, _, id, orientation in
            let owner = TouchListenerOwner.requireOwner(
                data,
                message: "wl_touch orientation fired without Swift state"
            )
            owner.append(
                .orientation(
                    RawTouchOrientation(
                        id: id,
                        orientation: WaylandFixed(rawValue: orientation)
                    )
                )
            )
        }
    }

    func install(on touch: OpaquePointer) throws {
        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = operations.addTouchListener(touch, callbacks)
        guard result == 0 else {
            throw RuntimeError.touchListenerInstallationFailed
        }
    }

    func cancel() {
        isCanceled = true
    }

    private static func requireOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String
    ) -> TouchListenerOwner {
        guard let data else {
            preconditionFailure(message())
        }

        return CallbackBox<TouchListenerOwner>
            .fromOpaque(data)
            .requireOwner(message())
    }

    private func append(_ event: RawTouchEvent) {
        guard !isCanceled, isCurrentDevice(deviceID) else { return }

        eventSink.append(
            RawInputEventDraft(
                seatID: deviceID.seatID,
                deviceID: deviceID,
                kind: .touch(event)
            )
        )
    }

    deinit {
        cancel()
    }
}
