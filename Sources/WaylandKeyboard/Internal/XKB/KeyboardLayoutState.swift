import CXKBCommonSystem
import Foundation
import WaylandRaw

package enum KeyboardInterpreterError: Error, Equatable, Sendable, CustomStringConvertible {
    case contextCreationFailed

    package var description: String {
        switch self {
        case .contextCreationFailed:
            "xkbcommon failed to create a context"
        }
    }
}

enum KeyboardLayoutError: Error, Equatable, Sendable, CustomStringConvertible {
    case contextCreationFailed
    case unsupportedKeymapFormat(UInt32)
    case emptyKeymap
    case invalidKeymap
    case stateCreationFailed
    case invalidKeycode(UInt32)

    var description: String {
        switch self {
        case .contextCreationFailed:
            "xkbcommon failed to create a context"
        case .unsupportedKeymapFormat(let format):
            "Unsupported keyboard keymap format \(format)"
        case .emptyKeymap:
            "Keyboard keymap payload is empty"
        case .invalidKeymap:
            "xkbcommon failed to create a keymap"
        case .stateCreationFailed:
            "xkbcommon failed to create keyboard state"
        case .invalidKeycode(let keycode):
            "Keyboard keycode \(keycode) cannot be converted to an XKB keycode"
        }
    }
}

@safe
final class XKBContextOwner {
    @safe let pointer: OpaquePointer

    init() throws(KeyboardLayoutError) {
        guard let newPointer = unsafe xkb_context_new(XKB_CONTEXT_NO_FLAGS) else {
            throw .contextCreationFailed
        }

        unsafe xkb_context_set_log_level(newPointer, XKB_LOG_LEVEL_CRITICAL)
        unsafe pointer = newPointer
    }

    deinit {
        unsafe xkb_context_unref(pointer)
    }
}

@safe
final class XKBKeymapOwner {
    @safe let pointer: OpaquePointer

    init(context: XKBContextOwner, payload: RawKeyboardKeymapPayload)
        throws(KeyboardLayoutError)
    {
        guard case .xkbV1(_, let bytes) = payload else {
            throw .unsupportedKeymapFormat(payload.format.rawValue)
        }

        let newPointer = unsafe bytes.rawValue.withUnsafeBytes { rawBuffer -> OpaquePointer? in
            guard let baseAddress = rawBuffer.baseAddress else {
                return nil
            }

            return unsafe xkb_keymap_new_from_buffer(
                context.pointer,
                baseAddress.assumingMemoryBound(to: CChar.self),
                bytes.count,
                XKB_KEYMAP_FORMAT_TEXT_V1,
                XKB_KEYMAP_COMPILE_NO_FLAGS
            )
        }

        guard let newPointer = unsafe newPointer else {
            throw .invalidKeymap
        }

        unsafe pointer = newPointer
    }

    deinit {
        unsafe xkb_keymap_unref(pointer)
    }
}

@safe
final class XKBStateOwner {
    @safe let pointer: OpaquePointer

    init(keymap: XKBKeymapOwner) throws(KeyboardLayoutError) {
        guard let newPointer = unsafe xkb_state_new(keymap.pointer) else {
            throw .stateCreationFailed
        }

        unsafe pointer = newPointer
    }

    deinit {
        unsafe xkb_state_unref(pointer)
    }
}

final class KeyboardLayoutState {
    private static let evdevToXKBOffset: UInt32 = 8

    private let keymapID: RawKeyboardKeymapID
    private let context: XKBContextOwner
    private let keymap: XKBKeymapOwner
    private let state: XKBStateOwner
    private let composeState: XKBComposeStateOwner?
    private let composeCancellationPolicy: KeyboardComposeCancellationPolicy
    let composeFailureReason: KeyboardInterpretationUnavailableReason?
    private let threadAffinity = ThreadAffinity()

    init(
        context sharedContext: XKBContextOwner,
        keymap payload: RawKeyboardKeymapPayload,
        composeTable: XKBComposeTableOwner? = nil,
        composeCancellationPolicy policy: KeyboardComposeCancellationPolicy =
            .passThroughCancellingKey
    ) throws(KeyboardLayoutError) {
        keymapID = payload.id
        context = sharedContext
        keymap = try XKBKeymapOwner(context: sharedContext, payload: payload)
        state = try XKBStateOwner(keymap: keymap)
        if let composeTable {
            do {
                composeState = try XKBComposeStateOwner(table: composeTable)
                composeFailureReason = nil
            } catch {
                composeState = nil
                composeFailureReason = .composeStateCreationFailed
            }
        } else {
            composeState = nil
            composeFailureReason = nil
        }
        composeCancellationPolicy = policy
    }

    init(keymap payload: RawKeyboardKeymapPayload)
        throws(KeyboardLayoutError)
    {
        let newContext = try XKBContextOwner()
        keymapID = payload.id
        context = newContext
        keymap = try XKBKeymapOwner(context: newContext, payload: payload)
        state = try XKBStateOwner(keymap: keymap)
        composeState = nil
        composeCancellationPolicy = .passThroughCancellingKey
        composeFailureReason = nil
    }

    var id: RawKeyboardKeymapID {
        threadAffinity.preconditionIsOwnerThread()
        return keymapID
    }

    func applyModifiers(_ modifiers: RawKeyboardModifiers) -> XKBStateComponents {
        threadAffinity.preconditionIsOwnerThread()

        let changed = unsafe xkb_state_update_mask(
            state.pointer,
            modifiers.depressed,
            modifiers.latched,
            modifiers.locked,
            0,
            0,
            modifiers.group
        )
        return XKBStateComponents(rawValue: UInt32(changed.rawValue))
    }

    func modifierMask(named name: String) -> UInt32? {
        threadAffinity.preconditionIsOwnerThread()

        return unsafe name.withCString { namePointer -> UInt32? in
            let index = unsafe xkb_keymap_mod_get_index(keymap.pointer, namePointer)
            guard index != XKB_MOD_INVALID, index < UInt32.bitWidth else {
                return nil
            }

            return UInt32(1) << index
        }
    }

    func interpret(_ key: RawKeyboardKey) throws(KeyboardLayoutError)
        -> InterpretedKeyboardKey
    {
        threadAffinity.preconditionIsOwnerThread()

        guard key.evdevKeycode <= UInt32.max - Self.evdevToXKBOffset else {
            throw .invalidKeycode(key.evdevKeycode)
        }

        let xkbKeycode = key.evdevKeycode + Self.evdevToXKBOffset
        let interpretedState = InterpretedKeyboardKeyState(rawValue: key.state.rawValue)
        let keyboardKeysyms = keysyms(for: xkbKeycode)
        let symbolResolution = symbolResolution(for: xkbKeycode, keysyms: keyboardKeysyms)
        let primaryKeysym = symbolResolution.primary
        let keyKeysymName = keysymName(for: primaryKeysym.rawValue)
        let isPressLike = interpretedState == .pressed || interpretedState == .repeated
        let keyText = isPressLike ? utf8Text(for: xkbKeycode) : nil
        let singleKeysym = keyboardKeysyms.count == 1 ? primaryKeysym : nil
        let singleKeysymName = singleKeysym == nil ? nil : keyKeysymName
        let textInput = KeyboardTextResolutionInput(
            feedKeysym: singleKeysym ?? KeyboardKeysym(rawValue: UInt32(XKB_KEY_NoSymbol)),
            feedKeysymName: singleKeysymName,
            keyText: keyText,
            resultKeysym: singleKeysym,
            resultKeysymName: singleKeysymName
        )
        let repeatCapability = KeyboardKeyRepeatCapability(
            keymapAllowsRepeat: unsafe xkb_keymap_key_repeats(keymap.pointer, xkbKeycode) != 0
        )
        let interpretation = InterpretedKeyboardKeyInterpretation(
            state: interpretedState,
            keysymName: keyKeysymName,
            utf8: keyText,
            repeatCapability: repeatCapability
        )
        let text = keyboardTextResult(
            isPressLike: isPressLike,
            input: textInput
        )

        return InterpretedKeyboardKey(
            serial: key.serial,
            time: key.time,
            evdevKeycode: key.evdevKeycode,
            xkbKeycode: xkbKeycode,
            symbolResolution: symbolResolution,
            interpretation: interpretation,
            text: text
        )
    }

    deinit {
        threadAffinity.preconditionIsOwnerThread()
    }

    private func keysymName(for keysym: UInt32) -> String? {
        var buffer = [CChar](repeating: 0, count: 64)
        let required = unsafe xkb_keysym_get_name(keysym, &buffer, buffer.count)
        guard required > 0 else { return nil }

        if Int(required) < buffer.count {
            return stringFromNullTerminatedBuffer(buffer)
        }

        buffer = [CChar](repeating: 0, count: Int(required) + 1)
        let written = unsafe xkb_keysym_get_name(keysym, &buffer, buffer.count)
        guard written > 0 else { return nil }

        return stringFromNullTerminatedBuffer(buffer)
    }

    private func keysyms(for xkbKeycode: UInt32) -> [KeyboardKeysym] {
        var keysymsPointer: UnsafePointer<xkb_keysym_t>?
        let count = unsafe xkb_state_key_get_syms(
            state.pointer,
            xkbKeycode,
            &keysymsPointer
        )
        guard count > 0, let keysymsPointer = unsafe keysymsPointer else { return [] }

        return (0..<Int(count)).map { index in
            KeyboardKeysym(rawValue: unsafe keysymsPointer[index])
        }
    }

    private func symbolResolution(
        for xkbKeycode: UInt32,
        keysyms: [KeyboardKeysym]
    ) -> KeyboardSymbolResolution {
        let oneKeysym = unsafe xkb_state_key_get_one_sym(state.pointer, xkbKeycode)
        guard oneKeysym != XKB_KEY_NoSymbol else {
            return .resolved(keysyms)
        }

        let primaryKeysym = KeyboardKeysym(rawValue: oneKeysym)
        guard keysyms.first != primaryKeysym else {
            return .resolved(keysyms)
        }

        let normalizedKeysyms = [primaryKeysym] + keysyms.filter { $0 != primaryKeysym }
        return .resolved(normalizedKeysyms)
    }

    private func utf8Text(for xkbKeycode: UInt32) -> String? {
        unsafe stringFromXKB { buffer, count in
            unsafe xkb_state_key_get_utf8(state.pointer, xkbKeycode, buffer, count)
        }
    }

    private func keyboardTextResult(
        isPressLike: Bool,
        input: KeyboardTextResolutionInput
    ) -> KeyboardTextResult {
        guard isPressLike else { return .none }

        guard let composeState else {
            return xkbKeyTextResult(
                input.keyText,
                resultKeysym: input.resultKeysym,
                resultKeysymName: input.resultKeysymName
            )
        }

        return composeState.resolve(
            input: input,
            policy: composeCancellationPolicy
        )
    }

    private func xkbKeyTextResult(
        _ keyText: String?,
        resultKeysym: KeyboardKeysym?,
        resultKeysymName: String?
    ) -> KeyboardTextResult {
        guard let keyText else { return .none }
        return .committed(
            KeyboardTextCommit(
                string: keyText,
                source: .xkbKey,
                resultKeysym: resultKeysym,
                resultKeysymName: resultKeysymName
            )
        )
    }

    private func stringFromXKB(
        _ body: (UnsafeMutablePointer<CChar>?, Int) -> Int32
    ) -> String? {
        let required = body(nil, 0)
        guard required > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: Int(required) + 1)
        let written = unsafe body(&buffer, buffer.count)
        guard written > 0 else { return nil }

        let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
        return String(
            bytes: buffer[..<endIndex].map { UInt8(bitPattern: $0) },
            encoding: .utf8
        )
    }

    private func stringFromNullTerminatedBuffer(_ buffer: [CChar]) -> String? {
        let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
        return String(
            bytes: buffer[..<endIndex].map { UInt8(bitPattern: $0) },
            encoding: .utf8
        )
    }
}
