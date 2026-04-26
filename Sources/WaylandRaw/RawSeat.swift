// swiftlint:disable file_length
import CWaylandProtocols
import Glibc

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

private enum SeatListenerEvent {
    case capabilities(SeatCapabilities)
    case name(String)
}

private final class SeatListenerOwner {
    private let operations: RawSeatProxyOperations
    private var onEvent: ((SeatListenerEvent) -> Void)?
    private var isCanceled = false
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_seat_listener_callbacks()
    )

    private var callbacks: UnsafeMutablePointer<swl_seat_listener_callbacks> {
        listenerStorage.callbacks
    }

    init(operations seatOperations: RawSeatProxyOperations) {
        operations = seatOperations

        callbacks.pointee.capabilities = { data, _, capabilities in
            guard let data else {
                preconditionFailure("wl_seat capabilities fired without Swift state")
            }

            let owner = CallbackBox<SeatListenerOwner>
                .fromOpaque(data)
                .requireOwner()

            guard !owner.isCanceled else { return }

            owner.onEvent?(.capabilities(SeatCapabilities(rawValue: capabilities)))
        }

        callbacks.pointee.name = { data, _, name in
            guard let data, let name else {
                preconditionFailure("wl_seat name fired without Swift state")
            }

            let owner = CallbackBox<SeatListenerOwner>
                .fromOpaque(data)
                .requireOwner()

            guard !owner.isCanceled else { return }

            owner.onEvent?(.name(String(cString: name)))
        }
    }

    func install(on seat: OpaquePointer, onEvent handleEvent: @escaping (SeatListenerEvent) -> Void)
        throws
    {
        onEvent = handleEvent
        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        let result = operations.addSeatListener(seat, callbacks)
        guard result == 0 else {
            throw RuntimeError.seatListenerInstallationFailed
        }
    }

    func cancel() {
        isCanceled = true
        onEvent = nil
    }

    deinit {
        cancel()
    }
}

private final class PointerListenerOwner {
    private let deviceID: RawInputDeviceID
    private let eventSink: RawInputEventSink
    private let operations: RawSeatProxyOperations
    private let isCurrentDevice: (RawInputDeviceID) -> Bool
    private var isCanceled = false
    private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: swl_pointer_listener_callbacks()
    )

    private var callbacks: UnsafeMutablePointer<swl_pointer_listener_callbacks> {
        listenerStorage.callbacks
    }

    // swiftlint:disable:next function_body_length
    init(
        deviceID pointerDeviceID: RawInputDeviceID,
        eventSink pointerEventSink: RawInputEventSink,
        operations pointerOperations: RawSeatProxyOperations,
        isCurrentDevice isPointerCurrent: @escaping (RawInputDeviceID) -> Bool
    ) {
        deviceID = pointerDeviceID
        eventSink = pointerEventSink
        operations = pointerOperations
        isCurrentDevice = isPointerCurrent

        callbacks.pointee.enter = { data, _, serial, surface, surfaceX, surfaceY in
            let owner = PointerListenerOwner.requireOwner(
                data, message: "wl_pointer enter fired without Swift state")
            owner.append(
                .enter(
                    RawPointerEnter(
                        serial: serial,
                        surfaceID: owner.operations.proxyObjectID(surface),
                        x: WaylandFixed(rawValue: surfaceX),
                        y: WaylandFixed(rawValue: surfaceY)
                    )
                )
            )
        }

        callbacks.pointee.leave = { data, _, serial, surface in
            let owner = PointerListenerOwner.requireOwner(
                data, message: "wl_pointer leave fired without Swift state")
            owner.append(
                .leave(
                    RawPointerLeave(
                        serial: serial,
                        surfaceID: owner.operations.proxyObjectID(surface)
                    )
                )
            )
        }

        callbacks.pointee.motion = { data, _, time, surfaceX, surfaceY in
            let owner = PointerListenerOwner.requireOwner(
                data, message: "wl_pointer motion fired without Swift state")
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

        callbacks.pointee.button = { data, _, serial, time, button, state in
            let owner = PointerListenerOwner.requireOwner(
                data, message: "wl_pointer button fired without Swift state")
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

        callbacks.pointee.axis = { data, _, time, axis, value in
            let owner = PointerListenerOwner.requireOwner(
                data, message: "wl_pointer axis fired without Swift state")
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

        callbacks.pointee.frame = { data, _ in
            let owner = PointerListenerOwner.requireOwner(
                data, message: "wl_pointer frame fired without Swift state")
            owner.append(.axis(.frame))
        }

        callbacks.pointee.axis_source = { data, _, axisSource in
            let owner = PointerListenerOwner.requireOwner(
                data,
                message: "wl_pointer axis_source fired without Swift state"
            )
            owner.append(.axis(.source(RawPointerAxisSource(rawValue: axisSource))))
        }

        callbacks.pointee.axis_stop = { data, _, time, axis in
            let owner = PointerListenerOwner.requireOwner(
                data,
                message: "wl_pointer axis_stop fired without Swift state"
            )
            owner.append(.axis(.stop(time: time, axis: RawPointerAxis(rawValue: axis))))
        }

        callbacks.pointee.axis_discrete = { data, _, axis, discrete in
            let owner = PointerListenerOwner.requireOwner(
                data,
                message: "wl_pointer axis_discrete fired without Swift state"
            )
            owner.append(.axis(.discrete(axis: RawPointerAxis(rawValue: axis), value: discrete)))
        }

        callbacks.pointee.axis_value120 = { data, _, axis, value120 in
            let owner = PointerListenerOwner.requireOwner(
                data,
                message: "wl_pointer axis_value120 fired without Swift state"
            )
            owner.append(
                .axis(.value120(axis: RawPointerAxis(rawValue: axis), value120: value120))
            )
        }

        callbacks.pointee.axis_relative_direction = { data, _, axis, direction in
            let owner = PointerListenerOwner.requireOwner(
                data,
                message: "wl_pointer axis_relative_direction fired without Swift state"
            )
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

    func install(on pointer: OpaquePointer) throws {
        callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = operations.addPointerListener(pointer, callbacks)
        guard result == 0 else {
            throw RuntimeError.pointerListenerInstallationFailed
        }
    }

    func cancel() {
        isCanceled = true
    }

    private static func requireOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String
    ) -> PointerListenerOwner {
        guard let data else {
            preconditionFailure(message())
        }

        return CallbackBox<PointerListenerOwner>
            .fromOpaque(data)
            .requireOwner(message())
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

private final class KeyboardListenerOwner {
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
                bytes: try KeyboardListenerOwner.readKeymap(fd: fd, size: size)
            )
            keymapGeneration += 1
            append(.keymap(payload))
        } catch {
            onError(error)
        }
    }

    private static func readKeymap(fd: Int32, size: UInt32) throws -> [UInt8] {
        guard fd >= 0 else {
            return []
        }

        var fileDescriptor = RawFileDescriptor(fd)
        defer { fileDescriptor.close() }

        guard size > 0 else {
            return []
        }

        var bytes = [UInt8](repeating: 0, count: Int(size))
        var offset = 0

        while offset < bytes.count {
            let remainingCount = bytes.count - offset
            let readCount = bytes.withUnsafeMutableBytes { rawBytes in
                read(
                    fileDescriptor.rawValue,
                    rawBytes.baseAddress?.advanced(by: offset),
                    remainingCount
                )
            }

            if readCount < 0 {
                if errno == EINTR {
                    continue
                }
                throw RuntimeError.systemError(errno: errno)
            }

            if readCount == 0 {
                break
            }

            offset += readCount
        }

        if offset < bytes.count {
            bytes.removeSubrange(offset..<bytes.count)
        }

        return bytes
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

private final class TouchListenerOwner {
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

package final class RawInputChildProxy {
    package let id: RawInputDeviceID
    package let version: RawVersion

    private let listenerOwner: AnyObject?
    private let cancelListener: (() -> Void)?
    private var proxy: RawOwnedProxy

    package var pointer: OpaquePointer {
        proxy.pointer
    }

    package init(
        id childID: RawInputDeviceID,
        pointer childPointer: OpaquePointer,
        version childVersion: RawVersion,
        listenerOwner childListenerOwner: AnyObject?,
        cancelListener cancelChildListener: (() -> Void)? = nil,
        release releaseChildProxy: @escaping (OpaquePointer) -> Void
    ) {
        id = childID
        version = childVersion
        listenerOwner = childListenerOwner
        cancelListener = cancelChildListener
        proxy = RawOwnedProxy(pointer: childPointer, destroy: releaseChildProxy)
    }

    package func destroy() {
        cancelListener?()
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

// swiftlint:disable:next type_body_length
public final class RawSeat {
    package let id: RawSeatID
    let pointer: OpaquePointer
    public let version: RawVersion

    private let eventSink: RawInputEventSink
    private let listenerOwner: SeatListenerOwner
    private let operations: RawSeatProxyOperations
    private var state = SeatState()
    private var nameStorage: String?
    private var pointerDevice: RawInputChildProxy?
    private var keyboardDevice: RawInputChildProxy?
    private var touchDevice: RawInputChildProxy?
    private var isDestroyed = false

    package private(set) var lastCapabilityError: Error?

    package var advertisedCapabilities: SeatCapabilities {
        state.advertisedCapabilities
    }

    package var activeCapabilities: SeatCapabilities {
        state.activeCapabilities
    }

    package var name: String? {
        nameStorage
    }

    package init(
        id seatID: RawSeatID,
        pointer seatPointer: OpaquePointer,
        version seatVersion: RawVersion,
        eventSink inputEventSink: RawInputEventSink,
        operations seatOperations: RawSeatProxyOperations = .live,
        installListener: Bool = true
    ) throws {
        id = seatID
        pointer = seatPointer
        version = seatVersion
        eventSink = inputEventSink
        operations = seatOperations
        listenerOwner = SeatListenerOwner(operations: seatOperations)

        guard installListener else { return }

        try listenerOwner.install(on: seatPointer) { [weak seat = self] event in
            seat?.handleSeatEvent(event)
        }
    }

    package var snapshot: RawSeatEventSnapshot {
        RawSeatEventSnapshot(
            advertisedCapabilities: state.advertisedCapabilities,
            activeCapabilities: state.activeCapabilities,
            name: nameStorage
        )
    }

    package func applyCapabilities(_ capabilities: SeatCapabilities) throws {
        let plan = reduceSeatState(
            state,
            seatID: id,
            action: .capabilitiesChanged(capabilities)
        )
        try apply(plan)
    }

    package func applyName(_ name: String) {
        nameStorage = name
        appendSnapshot()
    }

    package func handleRemovedGlobal() {
        let plan = reduceSeatState(state, seatID: id, action: .removed)
        do {
            try apply(plan)
        } catch {
            lastCapabilityError = error
        }
        destroy()
    }

    package func destroy() {
        guard !isDestroyed else { return }

        isDestroyed = true
        destroyTouch()
        destroyKeyboard()
        destroyPointer()
        listenerOwner.cancel()
        operations.releaseSeat(pointer)
    }

    private func handleSeatEvent(_ event: SeatListenerEvent) {
        do {
            switch event {
            case .capabilities(let capabilities):
                try applyCapabilities(capabilities)
            case .name(let name):
                applyName(name)
            }
        } catch {
            lastCapabilityError = error
        }
    }

    private func apply(_ plan: SeatTransitionPlan) throws {
        state = plan.nextState
        var firstError: Error?

        for effect in plan.effects {
            if let error = applyCreateEffect(effect) {
                firstError = firstError ?? error
                continue
            }

            if applyDestroyEffect(effect) {
                continue
            }

            applyEmissionEffect(effect)
        }

        if let firstError {
            throw firstError
        }
    }

    private func applyCreateEffect(_ effect: SeatEffect) -> Error? {
        switch effect {
        case .createPointer(let deviceID):
            attemptCreate(action: .pointerCreateFailed) {
                try createPointer(id: deviceID)
            }
        case .createKeyboard(let deviceID):
            attemptCreate(action: .keyboardCreateFailed) {
                try createKeyboard(id: deviceID)
            }
        case .createTouch(let deviceID):
            attemptCreate(action: .touchCreateFailed) {
                try createTouch(id: deviceID)
            }
        default:
            nil
        }
    }

    private func attemptCreate(action failureAction: SeatAction, _ create: () throws -> Void)
        -> Error?
    {
        do {
            try create()
            return nil
        } catch {
            state = reduceSeatState(state, seatID: id, action: failureAction).nextState
            return error
        }
    }

    private func applyDestroyEffect(_ effect: SeatEffect) -> Bool {
        switch effect {
        case .destroyPointer:
            destroyPointer()
            return true
        case .destroyKeyboard:
            destroyKeyboard()
            return true
        case .destroyTouch:
            destroyTouch()
            return true
        default:
            return false
        }
    }

    private func applyEmissionEffect(_ effect: SeatEffect) {
        switch effect {
        case .emitSeatSnapshot:
            appendSnapshot()
        case .emitSeatRemoved:
            appendSeatRemoved()
        default:
            break
        }
    }

    private func createPointer(id deviceID: RawInputDeviceID) throws {
        guard pointerDevice == nil else { return }
        guard let childPointer = operations.getPointer(pointer) else {
            throw RuntimeError.bindFailed("wl_pointer")
        }

        let listenerOwner = PointerListenerOwner(
            deviceID: deviceID,
            eventSink: eventSink,
            operations: operations
        ) { [weak seat = self] deviceID in
            seat?.isCurrentDevice(deviceID) == true
        }
        do {
            try listenerOwner.install(on: childPointer)
        } catch {
            operations.releasePointer(childPointer)
            throw error
        }

        pointerDevice = RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: operations.proxyVersion(childPointer),
            listenerOwner: listenerOwner,
            cancelListener: { listenerOwner.cancel() },
            release: operations.releasePointer
        )
    }

    private func createKeyboard(id deviceID: RawInputDeviceID) throws {
        guard keyboardDevice == nil else { return }
        guard let childPointer = operations.getKeyboard(pointer) else {
            throw RuntimeError.bindFailed("wl_keyboard")
        }

        let listenerOwner = KeyboardListenerOwner(
            deviceID: deviceID,
            eventSink: eventSink,
            operations: operations,
            isCurrentDevice: { [weak seat = self] deviceID in
                seat?.isCurrentDevice(deviceID) == true
            },
            onError: { [weak seat = self] error in
                seat?.lastCapabilityError = error
            }
        )
        do {
            try listenerOwner.install(on: childPointer)
        } catch {
            operations.releaseKeyboard(childPointer)
            throw error
        }

        keyboardDevice = RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: operations.proxyVersion(childPointer),
            listenerOwner: listenerOwner,
            cancelListener: { listenerOwner.cancel() },
            release: operations.releaseKeyboard
        )
    }

    private func createTouch(id deviceID: RawInputDeviceID) throws {
        guard touchDevice == nil else { return }
        guard let childPointer = operations.getTouch(pointer) else {
            throw RuntimeError.bindFailed("wl_touch")
        }

        let listenerOwner = TouchListenerOwner(
            deviceID: deviceID,
            eventSink: eventSink,
            operations: operations
        ) { [weak seat = self] deviceID in
            seat?.isCurrentDevice(deviceID) == true
        }
        do {
            try listenerOwner.install(on: childPointer)
        } catch {
            operations.releaseTouch(childPointer)
            throw error
        }

        touchDevice = RawInputChildProxy(
            id: deviceID,
            pointer: childPointer,
            version: operations.proxyVersion(childPointer),
            listenerOwner: listenerOwner,
            cancelListener: { listenerOwner.cancel() },
            release: operations.releaseTouch
        )
    }

    private func destroyPointer() {
        pointerDevice?.destroy()
        pointerDevice = nil
    }

    private func destroyKeyboard() {
        keyboardDevice?.destroy()
        keyboardDevice = nil
    }

    private func destroyTouch() {
        touchDevice?.destroy()
        touchDevice = nil
    }

    private func isCurrentDevice(_ deviceID: RawInputDeviceID) -> Bool {
        switch deviceID.kind {
        case .pointer:
            pointerDevice?.id == deviceID
        case .keyboard:
            keyboardDevice?.id == deviceID
        case .touch:
            touchDevice?.id == deviceID
        }
    }

    private func appendSnapshot() {
        eventSink.append(
            RawInputEventDraft(
                seatID: id,
                deviceID: nil,
                kind: .seat(snapshot)
            )
        )
    }

    private func appendSeatRemoved() {
        eventSink.append(
            RawInputEventDraft(
                seatID: id,
                deviceID: nil,
                kind: .seatRemoved
            )
        )
    }

    deinit {
        destroy()
    }
}
