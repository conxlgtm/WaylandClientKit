import CWaylandProtocols
import Glibc

@safe
final class KeyboardListenerOwner {
    private let deviceID: RawInputDeviceID
    private let eventSink: RawInputEventSink
    private let operations: RawSeatProxyOperations
    private let invariantFailureSink: RawInvariantFailureSink?
    private let isCurrentDevice: (RawInputDeviceID) -> Bool
    private let onError: (Error, RawKeyboardKeymapID?) -> Void
    private var keymapGeneration: UInt64 = 1
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_keyboard_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_keyboard_listener_callbacks> {
        listenerStorage.callbacks
    }

    // swiftlint:disable:next function_body_length
    init(
        deviceID keyboardDeviceID: RawInputDeviceID,
        eventSink keyboardEventSink: RawInputEventSink,
        operations keyboardOperations: RawSeatProxyOperations,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        isCurrentDevice isKeyboardCurrent: @escaping (RawInputDeviceID) -> Bool,
        onError handleError: @escaping (Error, RawKeyboardKeymapID?) -> Void
    ) {
        deviceID = keyboardDeviceID
        eventSink = keyboardEventSink
        operations = keyboardOperations
        invariantFailureSink = failureSink
        isCurrentDevice = isKeyboardCurrent
        onError = handleError

        unsafe callbacks.pointee.keymap = { data, _, format, fd, size in
            KeyboardListenerOwner.withOwner(
                data,
                message: "wl_keyboard keymap fired without Swift state"
            ) { owner in
                owner.handleKeymap(format: format, fd: fd, size: size)
            }
        }

        unsafe callbacks.pointee.enter = { data, _, serial, surface, keys in
            KeyboardListenerOwner.withOwner(
                data,
                message: "wl_keyboard enter fired without Swift state"
            ) { owner in
                owner.handleEnter(serial: serial, surface: surface, keys: keys)
            }
        }

        unsafe callbacks.pointee.leave = { data, _, serial, surface in
            KeyboardListenerOwner.withOwner(
                data,
                message: "wl_keyboard leave fired without Swift state"
            ) { owner in
                owner.append(
                    .leave(
                        RawKeyboardLeave(
                            serial: serial,
                            surfaceID: unsafe owner.operations.proxyObjectID(surface)
                        )
                    )
                )
            }
        }

        unsafe callbacks.pointee.key = { data, _, serial, time, key, state in
            KeyboardListenerOwner.withOwner(
                data,
                message: "wl_keyboard key fired without Swift state"
            ) { owner in
                owner.append(
                    .key(
                        RawKeyboardKey(
                            serial: serial,
                            time: time,
                            evdevKeycode: key,
                            state: RawKeyboardKeyState(rawValue: state)
                        )
                    )
                )
            }
        }

        unsafe callbacks.pointee.modifiers = { data, _, serial, depressed, latched, locked, group in
            KeyboardListenerOwner.withOwner(
                data,
                message: "wl_keyboard modifiers fired without Swift state"
            ) { owner in
                owner.append(
                    .modifiers(
                        RawKeyboardModifiers(
                            serial: serial,
                            depressed: depressed,
                            latched: latched,
                            locked: locked,
                            group: group
                        )
                    )
                )
            }
        }

        unsafe callbacks.pointee.repeat_info = { data, _, rate, delay in
            KeyboardListenerOwner.withOwner(
                data,
                message: "wl_keyboard repeat_info fired without Swift state"
            ) { owner in
                do {
                    owner.append(.repeatInfo(try RawKeyboardRepeatInfo(rate: rate, delay: delay)))
                } catch let error as RawKeyboardRepeatInfoError {
                    owner.appendDiagnostic(
                        .keyboardRepeat(RawKeyboardRepeatDiagnostic(error: error))
                    )
                } catch {
                    owner.appendDiagnostic(
                        .listener(
                            RawListenerDiagnostic(
                                listener: "wl_keyboard",
                                message: "unexpected repeat_info error: \(error)"
                            )
                        )
                    )
                }
            }
        }
    }

    func install(on keyboard: OpaquePointer) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe operations.addKeyboardListener(keyboard, callbacks)
        guard result == 0 else {
            throw RuntimeError.keyboardListenerInstallationFailed
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    @safe
    private func handleEnter(
        serial: UInt32,
        surface: OpaquePointer?,
        keys: UnsafeMutablePointer<wl_array>?
    ) {
        do {
            append(
                .enter(
                    RawKeyboardEnter(
                        serial: serial,
                        surfaceID: unsafe operations.proxyObjectID(surface),
                        pressedKeys: try WaylandArray.uint32Values(from: keys)
                    )
                )
            )
        } catch {
            onError(error, nil)
        }
    }

    private func handleKeymap(format rawFormat: UInt32, fd: Int32, size: UInt32) {
        guard !isCanceled, isCurrentDevice(deviceID) else {
            if fd >= 0 {
                close(fd)
            }
            return
        }

        let id = RawKeyboardKeymapID(
            seatID: deviceID.seatID,
            keyboardGeneration: deviceID.generation,
            keymapGeneration: keymapGeneration
        )
        defer {
            keymapGeneration += 1
        }

        do {
            let payload = try RawKeyboardKeymapReader.readKeymap(
                id: id,
                format: RawKeyboardKeymapFormat(rawValue: rawFormat),
                fd: fd,
                size: size
            )
            append(.keymap(payload))
        } catch {
            onError(error, id)
        }
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (KeyboardListenerOwner) -> Void
    ) {
        CListenerStorage<KeyboardListenerOwner, swl_keyboard_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }

    private func append(_ event: RawKeyboardEvent) {
        guard !isCanceled, isCurrentDevice(deviceID) else { return }

        eventSink.append(
            RawInputEventDraft(
                seatID: deviceID.seatID,
                deviceID: deviceID,
                kind: .keyboard(event)
            )
        )
    }

    private func appendDiagnostic(_ payload: RawInputDiagnosticPayload) {
        guard !isCanceled, isCurrentDevice(deviceID) else { return }

        eventSink.append(
            RawInputEventDraft(
                seatID: deviceID.seatID,
                deviceID: deviceID,
                kind: .diagnostic(RawInputDiagnostic(payload))
            )
        )
    }

    deinit {
        cancel()
    }
}
