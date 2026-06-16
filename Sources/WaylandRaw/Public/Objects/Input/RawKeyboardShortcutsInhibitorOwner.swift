import CWaylandProtocols
import Glibc

package enum RawKeyboardShortcutsInhibitorEvent: Equatable, Sendable {
    case active
    case inactive
}

@safe
package final class RawKeyboardShortcutsInhibitorOwner {
    private let onEvent: (RawKeyboardShortcutsInhibitorEvent) -> Void
    private let invariantFailureSink: RawInvariantFailureSink?
    private var isCanceled = false
    @safe private lazy var listenerStorage = CListenerStorage(
        owner: self,
        initialValue: unsafe swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_callbacks(),
        invariantFailureSink: invariantFailureSink
    )

    @safe private var callbacks:
        UnsafeMutablePointer<
            swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_callbacks
        >
    {
        listenerStorage.callbacks
    }

    init(
        onEvent eventHandler: @escaping (RawKeyboardShortcutsInhibitorEvent) -> Void,
        invariantFailureSink failureSink: RawInvariantFailureSink?
    ) {
        onEvent = eventHandler
        invariantFailureSink = failureSink

        installActiveCallback()
        installInactiveCallback()
    }

    private func installActiveCallback() {
        unsafe callbacks.pointee.active = { data, _ in
            RawKeyboardShortcutsInhibitorOwner.withOwner(
                data,
                message:
                    "zwp_keyboard_shortcuts_inhibitor_v1 active fired without Swift state"
            ) { owner in
                owner.append(.active)
            }
        }
    }

    private func installInactiveCallback() {
        unsafe callbacks.pointee.inactive = { data, _ in
            RawKeyboardShortcutsInhibitorOwner.withOwner(
                data,
                message:
                    "zwp_keyboard_shortcuts_inhibitor_v1 inactive fired without Swift state"
            ) { owner in
                owner.append(.inactive)
            }
        }
    }

    func install(on inhibitor: OpaquePointer) throws {
        unsafe callbacks.pointee.data = listenerStorage.opaqueOwnerPointer
        let result = unsafe swl_zwp_keyboard_shortcuts_inhibitor_v1_add_listener(
            inhibitor,
            callbacks
        )
        guard result == 0 else {
            throw RuntimeError.systemError(
                errno: EINVAL,
                operation: .installListener("zwp_keyboard_shortcuts_inhibitor_v1")
            )
        }
    }

    func cancel() {
        isCanceled = true
        listenerStorage.invalidate()
    }

    private func append(_ event: RawKeyboardShortcutsInhibitorEvent) {
        guard !isCanceled else { return }

        onEvent(event)
    }

    @safe
    private static func withOwner(
        _ data: UnsafeMutableRawPointer?,
        message: @autoclosure () -> String,
        _ body: (RawKeyboardShortcutsInhibitorOwner) -> Void
    ) {
        CListenerStorage<
            RawKeyboardShortcutsInhibitorOwner,
            swl_zwp_keyboard_shortcuts_inhibitor_v1_listener_callbacks
        >.withOwner(from: data, message: message(), body)
    }
}
