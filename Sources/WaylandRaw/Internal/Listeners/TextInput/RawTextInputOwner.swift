import CWaylandClientSystem
import CWaylandProtocols

@safe
package final class RawTextInputOwner {
    private let onEvent: (RawTextInputEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var installState = ListenerInstallState.idle
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_text_input_v3_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks: UnsafeMutablePointer<swl_text_input_v3_listener_callbacks> {
        listenerStorage.callbacks
    }

    package init(
        onEvent eventHandler: @escaping (RawTextInputEvent) -> Void,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        onEvent = eventHandler
        invariantFailureSink = failureSink
        configureCallbacks()
    }

    package func install(on textInput: RawTextInput) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer

        try installState.install(interface: "zwp_text_input_v3") {
            unsafe swl_text_input_v3_add_listener(textInput.pointer, callbacks)
        }
    }

    package func cancel() {
        listenerStorage.invalidate()
    }

    private func configureCallbacks() {
        configureFocusCallbacks()
        configureTextCallbacks()
        configureActionCallbacks()
    }

    private func configureFocusCallbacks() {
        unsafe callbacks.pointee.enter = { data, _, surface in
            RawTextInputOwner.withOwner(
                data,
                message: "zwp_text_input_v3 enter fired without Swift state"
            ) { owner in
                owner.onEvent(.enter(surfaceID: RawTextInputOwner.surfaceID(surface)))
            }
        }
        unsafe callbacks.pointee.leave = { data, _, surface in
            RawTextInputOwner.withOwner(
                data,
                message: "zwp_text_input_v3 leave fired without Swift state"
            ) { owner in
                owner.onEvent(.leave(surfaceID: RawTextInputOwner.surfaceID(surface)))
            }
        }
    }

    private func configureTextCallbacks() {
        unsafe callbacks.pointee.preedit_string = { data, _, text, cursorBegin, cursorEnd in
            RawTextInputOwner.withOwner(
                data,
                message: "zwp_text_input_v3 preedit_string fired without Swift state"
            ) { owner in
                owner.onEvent(
                    .preeditString(
                        RawTextInputPreedit(
                            text: stringFromNullableCString(text),
                            cursorBegin: cursorBegin,
                            cursorEnd: cursorEnd
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.commit_string = { data, _, text in
            RawTextInputOwner.withOwner(
                data,
                message: "zwp_text_input_v3 commit_string fired without Swift state"
            ) { owner in
                owner.onEvent(.commitString(stringFromNullableCString(text)))
            }
        }
        unsafe callbacks.pointee.delete_surrounding_text = { data, _, before, after in
            RawTextInputOwner.withOwner(
                data,
                message: "zwp_text_input_v3 delete_surrounding_text fired without Swift state"
            ) { owner in
                owner.onEvent(.deleteSurroundingText(beforeLength: before, afterLength: after))
            }
        }
        unsafe callbacks.pointee.done = { data, _, serial in
            RawTextInputOwner.withOwner(
                data,
                message: "zwp_text_input_v3 done fired without Swift state"
            ) { owner in
                owner.onEvent(.done(serial: serial))
            }
        }
    }

    private func configureActionCallbacks() {
        unsafe callbacks.pointee.action = { data, _, action, serial in
            RawTextInputOwner.withOwner(
                data,
                message: "zwp_text_input_v3 action fired without Swift state"
            ) { owner in
                owner.onEvent(
                    .action(
                        RawTextInputActionEvent(
                            action: RawTextInputAction(rawValue: action),
                            serial: serial
                        )
                    )
                )
            }
        }
        unsafe callbacks.pointee.language = { data, _, language in
            RawTextInputOwner.withOwner(
                data,
                message: "zwp_text_input_v3 language fired without Swift state"
            ) { owner in
                owner.onEvent(.language(stringFromNullableCString(language)))
            }
        }
        unsafe callbacks.pointee.preedit_hint = { data, _, start, end, hint in
            RawTextInputOwner.withOwner(
                data,
                message: "zwp_text_input_v3 preedit_hint fired without Swift state"
            ) { owner in
                owner.onEvent(
                    .preeditHint(
                        RawTextInputPreeditHint(start: start, end: end, hint: hint)
                    )
                )
            }
        }
    }

    @safe
    private static func surfaceID(_ surface: OpaquePointer?) -> RawObjectID? {
        guard let surface = unsafe surface else {
            return nil
        }

        return unsafe RawObjectID(
            swl_proxy_get_id(UnsafeMutableRawPointer(surface))
        )
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawTextInputOwner) -> Void
    ) {
        CListenerStorage<RawTextInputOwner, swl_text_input_v3_listener_callbacks>
            .withOwner(from: data, message: message(), body)
    }
}
