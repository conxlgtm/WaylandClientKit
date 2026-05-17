import CWaylandProtocols

package struct RawTextInputChangeCause: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue causeRawValue: UInt32) {
        rawValue = causeRawValue
    }

    package static let inputMethod = Self(rawValue: 0)
    package static let other = Self(rawValue: 1)
}

package struct RawTextInputContentHint: OptionSet, Sendable {
    package let rawValue: UInt32

    package init(rawValue hintRawValue: UInt32) {
        rawValue = hintRawValue
    }

    package static let completion = Self(rawValue: 0x1)
    package static let spellcheck = Self(rawValue: 0x2)
    package static let autoCapitalization = Self(rawValue: 0x4)
    package static let lowercase = Self(rawValue: 0x8)
    package static let uppercase = Self(rawValue: 0x10)
    package static let titlecase = Self(rawValue: 0x20)
    package static let hiddenText = Self(rawValue: 0x40)
    package static let sensitiveData = Self(rawValue: 0x80)
    package static let latin = Self(rawValue: 0x100)
    package static let multiline = Self(rawValue: 0x200)
    package static let onScreenInputProvided = Self(rawValue: 0x400)
    package static let noEmoji = Self(rawValue: 0x800)
    package static let preeditShown = Self(rawValue: 0x1000)
}

package struct RawTextInputContentPurpose: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue purposeRawValue: UInt32) {
        rawValue = purposeRawValue
    }

    package static let normal = Self(rawValue: 0)
    package static let alpha = Self(rawValue: 1)
    package static let digits = Self(rawValue: 2)
    package static let number = Self(rawValue: 3)
    package static let phone = Self(rawValue: 4)
    package static let url = Self(rawValue: 5)
    package static let email = Self(rawValue: 6)
    package static let name = Self(rawValue: 7)
    package static let password = Self(rawValue: 8)
    package static let pin = Self(rawValue: 9)
    package static let date = Self(rawValue: 10)
    package static let time = Self(rawValue: 11)
    package static let datetime = Self(rawValue: 12)
    package static let terminal = Self(rawValue: 13)
}

package struct RawTextInputAction: Equatable, Sendable {
    package let rawValue: UInt32

    package init(rawValue actionRawValue: UInt32) {
        rawValue = actionRawValue
    }

    package static let none = Self(rawValue: 0)
    package static let submit = Self(rawValue: 1)
}

package struct RawTextInputPreedit: Equatable, Sendable {
    package let text: String?
    package let cursorBegin: Int32
    package let cursorEnd: Int32

    package init(
        text preeditText: String?,
        cursorBegin preeditCursorBegin: Int32,
        cursorEnd preeditCursorEnd: Int32
    ) {
        text = preeditText
        cursorBegin = preeditCursorBegin
        cursorEnd = preeditCursorEnd
    }
}

package struct RawTextInputActionEvent: Equatable, Sendable {
    package let action: RawTextInputAction
    package let serial: UInt32

    package init(action eventAction: RawTextInputAction, serial eventSerial: UInt32) {
        action = eventAction
        serial = eventSerial
    }
}

package struct RawTextInputPreeditHint: Equatable, Sendable {
    package let start: UInt32
    package let end: UInt32
    package let hint: UInt32

    package init(
        start hintStart: UInt32,
        end hintEnd: UInt32,
        hint hintKind: UInt32
    ) {
        start = hintStart
        end = hintEnd
        hint = hintKind
    }
}

package enum RawTextInputEvent: Equatable, Sendable {
    case enter(surfaceID: RawObjectID?)
    case leave(surfaceID: RawObjectID?)
    case preeditString(RawTextInputPreedit)
    case commitString(String?)
    case deleteSurroundingText(beforeLength: UInt32, afterLength: UInt32)
    case done(serial: UInt32)
    case action(RawTextInputActionEvent)
    case language(String?)
    case preeditHint(RawTextInputPreeditHint)
}

@safe
package final class RawTextInputManager {
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
        proxy = try RawOwnedProxy(
            adopting: managerPointer,
            interface: "zwp_text_input_manager_v3",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_text_input_manager_v3_destroy
        )
        version = managerVersion
        proxyAdoption = adoptionContext
    }

    package func getTextInput(for seat: RawSeat) throws -> RawTextInput {
        guard
            let textInput = unsafe swl_text_input_manager_v3_get_text_input(
                pointer,
                seat.pointer
            )
        else {
            throw RuntimeError.bindFailed("zwp_text_input_v3")
        }

        return try .init(pointer: textInput, version: version, proxyAdoption: proxyAdoption)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}

@safe
package final class RawTextInput {
    package let version: RawVersion

    private var proxy: RawOwnedProxy

    @safe var pointer: OpaquePointer { proxy.pointer }

    @safe
    init(
        pointer textInputPointer: OpaquePointer,
        version textInputVersion: RawVersion,
        proxyAdoption adoptionContext: RawProxyAdoptionContext
    ) throws(RuntimeError) {
        proxy = try RawOwnedProxy(
            adopting: textInputPointer,
            interface: "zwp_text_input_v3",
            proxyAdoption: adoptionContext,
            destroy: unsafe swl_text_input_v3_destroy
        )
        version = textInputVersion
    }

    package func enable() {
        unsafe swl_text_input_v3_enable(pointer)
    }

    package func disable() {
        unsafe swl_text_input_v3_disable(pointer)
    }

    package func setSurroundingText(_ text: String, cursor: Int32, anchor: Int32) {
        unsafe text.withCString { textPointer in
            unsafe swl_text_input_v3_set_surrounding_text(
                pointer,
                textPointer,
                cursor,
                anchor
            )
        }
    }

    package func setTextChangeCause(_ cause: RawTextInputChangeCause) {
        unsafe swl_text_input_v3_set_text_change_cause(pointer, cause.rawValue)
    }

    package func setContentType(
        hint: RawTextInputContentHint,
        purpose: RawTextInputContentPurpose
    ) {
        unsafe swl_text_input_v3_set_content_type(
            pointer,
            hint.rawValue,
            purpose.rawValue
        )
    }

    package func setCursorRectangle(x: Int32, y: Int32, width: Int32, height: Int32) {
        unsafe swl_text_input_v3_set_cursor_rectangle(pointer, x, y, width, height)
    }

    package func commit() {
        unsafe swl_text_input_v3_commit(pointer)
    }

    package func destroy() {
        proxy.destroy()
    }

    deinit {
        destroy()
    }
}
