import CWaylandProtocols
import Testing

@Suite
struct ListenerCallbackBundleSmokeTests {
    @Test
    func pointerListenerCallbackBundleImportsIntoSwift() {
        var callbacks = swl_pointer_listener_callbacks()

        callbacks.enter = nil
        callbacks.leave = nil
        callbacks.motion = nil
        callbacks.button = nil
        callbacks.axis = nil
        callbacks.frame = nil
        callbacks.axis_source = nil
        callbacks.axis_stop = nil
        callbacks.axis_discrete = nil
        callbacks.axis_value120 = nil
        callbacks.axis_relative_direction = nil
        callbacks.data = nil

        #expect(callbacks.data == nil)
    }

    @Test
    func keyboardListenerCallbackBundleImportsIntoSwift() {
        var callbacks = swl_keyboard_listener_callbacks()

        callbacks.keymap = nil
        callbacks.enter = nil
        callbacks.leave = nil
        callbacks.key = nil
        callbacks.modifiers = nil
        callbacks.repeat_info = nil
        callbacks.data = nil

        #expect(callbacks.data == nil)
    }

    @Test
    func touchListenerCallbackBundleImportsIntoSwift() {
        var callbacks = swl_touch_listener_callbacks()

        callbacks.down = nil
        callbacks.up = nil
        callbacks.motion = nil
        callbacks.frame = nil
        callbacks.cancel = nil
        callbacks.shape = nil
        callbacks.orientation = nil
        callbacks.data = nil

        #expect(callbacks.data == nil)
    }
}
