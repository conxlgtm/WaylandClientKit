import CWaylandProtocols
import Glibc

final class KeyboardListenerOwner {
    private let deviceID: RawInputDeviceID
    private let eventSink: RawInputEventSink
    private let operations: RawSeatProxyOperations
    private let isCurrentDevice: (RawInputDeviceID) -> Bool
    private let onError: (Error) -> Void
    private var keymapGeneration: UInt64 = 1
    private var isCanceled = false
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_keyboard_listener_callbacks()
    )

    private var callbacks: UnsafeMutablePointer<swl_keyboard_listener_callbacks> {
        listenerStorage.callbacks
    }

    // swiftlint:disable:next function_body_length
    init(
        deviceID keyboardDeviceID: RawInputDeviceID,
        eventSink keyboardEventSink: RawInputEventSink,
        operations keyboardOperations: RawSeatProxyOperations,
        isCurrentDevice isKeyboardCurrent: @escaping (RawInputDeviceID) -> Bool,
        onError handleError: @escaping (Error) -> Void
    ) {
        deviceID = keyboardDeviceID
        eventSink = keyboardEventSink
        operations = keyboardOperations
        isCurrentDevice = isKeyboardCurrent
        onError = handleError

        callbacks.pointee.keymap = { data, _, format, fd, size in
            let owner = KeyboardListenerOwner.requireOwner(
                data,
                message: "wl_keyboard keymap fired without Swift state"
            )
            owner.handleKeymap(format: format, fd: fd, size: size)
        }

        callbacks.pointee.enter = { data, _, serial, surface, keys in
            let owner = KeyboardListenerOwner.requireOwner(
                data,
                message: "wl_keyboard enter fired without Swift state"
            )
            owner.handleEnter(serial: serial, surface: surface, keys: keys)
        }

        callbacks.pointee.leave = { data, _, serial, surface in
            let owner = KeyboardListenerOwner.requireOwner(
                data,
                message: "wl_keyboard leave fired without Swift state"
            )
            owner.append(
                .leave(
                    RawKeyboardLeave(
                        serial: serial,
                        surfaceID: owner.operations.proxyObjectID(surface)
                    )
                )
            )
        }

        callbacks.pointee.key = { data, _, serial, time, key, state in
            let owner = KeyboardListenerOwner.requireOwner(
                data,
                message: "wl_keyboard key fired without Swift state"
            )
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

        callbacks.pointee.modifiers = { data, _, serial, depressed, latched, locked, group in
            let owner = KeyboardListenerOwner.requireOwner(
                data,
                message: "wl_keyboard modifiers fired without Swift state"
            )
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

        callbacks.pointee.repeat_info = { data, _, rate, delay in
            let owner = KeyboardListenerOwner.requireOwner(
                data,
                message: "wl_keyboard repeat_info fired without Swift state"
            )
            owner.append(.repeatInfo(RawKeyboardRepeatInfo(rate: rate, delay: delay)))
        }
    }

    func install(on keyboard: OpaquePointer) throws {
        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = operations.addKeyboardListener(keyboard, callbacks)
        guard result == 0 else {
            throw RuntimeError.keyboardListenerInstallationFailed
        }
    }

    func cancel() {
        isCanceled = true
    }

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
                        surfaceID: operations.proxyObjectID(surface),
                        pressedKeys: try WaylandArray.uint32Values(from: keys)
                    )
                )
            )
        } catch {
            onError(error)
        }
    }

    private func handleKeymap(format rawFormat: UInt32, fd: Int32, size: UInt32) {
        guard !isCanceled, isCurrentDevice(deviceID) else {
            if fd >= 0 {
                close(fd)
            }
            return
        }

        do {
            let payload = RawKeyboardKeymapPayload(
                id: RawKeyboardKeymapID(
                    seatID: deviceID.seatID,
                    keyboardGeneration: deviceID.generation,
                    keymapGeneration: keymapGeneration
                ),
                format: RawKeyboardKeymapFormat(rawValue: rawFormat),
                size: size,
                bytes: try RawKeyboardKeymapReader.readKeymap(fd: fd, size: size)
            )
            keymapGeneration += 1
            append(.keymap(payload))
        } catch {
            onError(error)
        }
    }

    private static func requireOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String
    ) -> KeyboardListenerOwner {
        guard let data else {
            preconditionFailure(message())
        }

        return CallbackBox<KeyboardListenerOwner>
            .fromOpaque(data)
            .requireOwner(message())
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

    deinit {
        cancel()
    }
}
