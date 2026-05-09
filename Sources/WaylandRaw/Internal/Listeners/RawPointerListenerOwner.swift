import CWaylandProtocols

@safe
final class PointerListenerOwner {
    private let deviceID: RawInputDeviceID
    private let eventSink: RawInputEventSink
    private let operations: RawSeatProxyOperations
    private let invariantFailureSink: RawInvariantFailureSink?
    private let isCurrentDevice: (RawInputDeviceID) -> Bool
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_pointer_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_pointer_listener_callbacks> {
        listenerStorage.callbacks
    }

    // swiftlint:disable:next function_body_length
    init(
        deviceID pointerDeviceID: RawInputDeviceID,
        eventSink pointerEventSink: RawInputEventSink,
        operations pointerOperations: RawSeatProxyOperations,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        isCurrentDevice isPointerCurrent: @escaping (RawInputDeviceID) -> Bool
    ) {
        deviceID = pointerDeviceID
        eventSink = pointerEventSink
        operations = pointerOperations
        invariantFailureSink = failureSink
        isCurrentDevice = isPointerCurrent

        unsafe callbacks.pointee.enter = { data, _, serial, surface, surfaceX, surfaceY in
            PointerListenerOwner.withOwner(
                data,
                message: "wl_pointer enter fired without Swift state"
            ) { owner in
                owner.append(
                    .enter(
                        RawPointerEnter(
                            serial: serial,
                            surfaceID: unsafe owner.operations.proxyObjectID(surface),
                            x: WaylandFixed(rawValue: surfaceX),
                            y: WaylandFixed(rawValue: surfaceY)
                        )
                    )
                )
            }
        }

        unsafe callbacks.pointee.leave = { data, _, serial, surface in
            PointerListenerOwner.withOwner(
                data,
                message: "wl_pointer leave fired without Swift state"
            ) { owner in
                owner.append(
                    .leave(
                        RawPointerLeave(
                            serial: serial,
                            surfaceID: unsafe owner.operations.proxyObjectID(surface)
                        )
                    )
                )
            }
        }

        unsafe callbacks.pointee.motion = { data, _, time, surfaceX, surfaceY in
            PointerListenerOwner.withOwner(
                data,
                message: "wl_pointer motion fired without Swift state"
            ) { owner in
                owner.append(
                    .motion(
                        RawPointerMotion(
                            time: time,
                            x: WaylandFixed(rawValue: surfaceX),
                            y: WaylandFixed(rawValue: surfaceY)
                        )
                    )
                )
            }
        }

        unsafe callbacks.pointee.button = { data, _, serial, time, button, state in
            PointerListenerOwner.withOwner(
                data,
                message: "wl_pointer button fired without Swift state"
            ) { owner in
                owner.append(
                    .button(
                        RawPointerButton(
                            serial: serial,
                            time: time,
                            button: button,
                            state: RawPointerButtonState(rawValue: state)
                        )
                    )
                )
            }
        }

        unsafe callbacks.pointee.axis = { data, _, time, axis, value in
            PointerListenerOwner.withOwner(
                data,
                message: "wl_pointer axis fired without Swift state"
            ) { owner in
                owner.append(
                    .axis(
                        .axis(
                            time: time,
                            axis: RawPointerAxis(rawValue: axis),
                            value: WaylandFixed(rawValue: value)
                        )
                    )
                )
            }
        }

        unsafe callbacks.pointee.frame = { data, _ in
            PointerListenerOwner.withOwner(
                data,
                message: "wl_pointer frame fired without Swift state"
            ) { owner in
                owner.append(.axis(.frame))
            }
        }

        unsafe callbacks.pointee.axis_source = { data, _, axisSource in
            PointerListenerOwner.withOwner(
                data,
                message: "wl_pointer axis_source fired without Swift state"
            ) { owner in
                owner.append(.axis(.source(RawPointerAxisSource(rawValue: axisSource))))
            }
        }

        unsafe callbacks.pointee.axis_stop = { data, _, time, axis in
            PointerListenerOwner.withOwner(
                data,
                message: "wl_pointer axis_stop fired without Swift state"
            ) { owner in
                owner.append(.axis(.stop(time: time, axis: RawPointerAxis(rawValue: axis))))
            }
        }

        unsafe callbacks.pointee.axis_discrete = { data, _, axis, discrete in
            PointerListenerOwner.withOwner(
                data,
                message: "wl_pointer axis_discrete fired without Swift state"
            ) { owner in
                owner.append(
                    .axis(.discrete(axis: RawPointerAxis(rawValue: axis), value: discrete))
                )
            }
        }

        unsafe callbacks.pointee.axis_value120 = { data, _, axis, value120 in
            PointerListenerOwner.withOwner(
                data,
                message: "wl_pointer axis_value120 fired without Swift state"
            ) { owner in
                owner.append(
                    .axis(.value120(axis: RawPointerAxis(rawValue: axis), value120: value120))
                )
            }
        }

        unsafe callbacks.pointee.axis_relative_direction = { data, _, axis, direction in
            PointerListenerOwner.withOwner(
                data,
                message: "wl_pointer axis_relative_direction fired without Swift state"
            ) { owner in
                owner.append(
                    .axis(
                        .relativeDirection(
                            axis: RawPointerAxis(rawValue: axis),
                            direction: RawPointerAxisRelativeDirection(rawValue: direction)
                        )
                    )
                )
            }
        }
    }

    func install(on pointer: OpaquePointer) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe operations.addPointerListener(pointer, callbacks)
        guard result == 0 else {
            throw RuntimeError.pointerListenerInstallationFailed
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (PointerListenerOwner) -> Void
    ) {
        CListenerStorage<PointerListenerOwner, swl_pointer_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }

    private func append(_ event: RawPointerEvent) {
        guard !isCanceled, isCurrentDevice(deviceID) else { return }

        eventSink.append(
            RawInputEventDraft(
                seatID: deviceID.seatID,
                deviceID: deviceID,
                kind: .pointer(event)
            )
        )
    }

    deinit {
        cancel()
    }
}
