import CWaylandProtocols
import Testing

@Suite
struct ListenerCallbackBundleSmokeTests {  // swiftlint:disable:this type_body_length
    @Test
    func proxyVersionShimImportsIntoSwift() {
        let getVersion = unsafe swl_proxy_get_version
        #expect(unsafe MemoryLayout.size(ofValue: getVersion) > 0)
    }
    @Test
    func pointerSetCursorShimImportsIntoSwift() {
        let setCursor = unsafe swl_pointer_set_cursor
        #expect(unsafe MemoryLayout.size(ofValue: setCursor) > 0)
    }
    @Test
    func shmFormatShimsResolveIntoSwift() {
        let xrgb8888 = swl_shm_format_xrgb8888
        let argb8888 = swl_shm_format_argb8888
        let xrgb8888Value = swl_shm_format_xrgb8888()
        let argb8888Value = swl_shm_format_argb8888()
        #expect(MemoryLayout.size(ofValue: xrgb8888) > 0)
        #expect(MemoryLayout.size(ofValue: argb8888) > 0)
        #expect(xrgb8888Value != argb8888Value)
    }
    @Test
    func pointerListenerCallbackBundleImportsIntoSwift() {
        var callbacks = unsafe swl_pointer_listener_callbacks()
        unsafe callbacks.enter = nil
        unsafe callbacks.leave = nil
        unsafe callbacks.motion = nil
        unsafe callbacks.button = nil
        unsafe callbacks.axis = nil
        unsafe callbacks.frame = nil
        unsafe callbacks.axis_source = nil
        unsafe callbacks.axis_stop = nil
        unsafe callbacks.axis_discrete = nil
        unsafe callbacks.axis_value120 = nil
        unsafe callbacks.axis_relative_direction = nil
        unsafe callbacks.data = nil
        #expect(unsafe callbacks.data == nil)
    }
    @Test
    func keyboardListenerCallbackBundleImportsIntoSwift() {
        var callbacks = unsafe swl_keyboard_listener_callbacks()
        unsafe callbacks.keymap = nil
        unsafe callbacks.enter = nil
        unsafe callbacks.leave = nil
        unsafe callbacks.key = nil
        unsafe callbacks.modifiers = nil
        unsafe callbacks.repeat_info = nil
        unsafe callbacks.data = nil
        #expect(unsafe callbacks.data == nil)
    }
    @Test
    func touchListenerCallbackBundleImportsIntoSwift() {
        var callbacks = unsafe swl_touch_listener_callbacks()
        unsafe callbacks.down = nil
        unsafe callbacks.up = nil
        unsafe callbacks.motion = nil
        unsafe callbacks.frame = nil
        unsafe callbacks.cancel = nil
        unsafe callbacks.shape = nil
        unsafe callbacks.orientation = nil
        unsafe callbacks.data = nil
        #expect(unsafe callbacks.data == nil)
    }
    @Test
    func seatListenerCallbackSignaturesImportIntoSwift() {
        var callbacks = unsafe swl_seat_listener_callbacks()
        unsafe callbacks.capabilities = { data, seat, capabilities in
            _ = unsafe data
            _ = unsafe seat
            _ = capabilities
        }
        unsafe callbacks.name = { data, seat, name in
            _ = unsafe data
            _ = unsafe seat
            _ = unsafe name
        }
        unsafe callbacks.data = nil
        #expect(unsafe callbacks.capabilities != nil)
        #expect(unsafe callbacks.name != nil)
    }
    @Test
    func pointerListenerCallbackSignaturesImportIntoSwift() {
        var callbacks = unsafe swl_pointer_listener_callbacks()
        unsafe callbacks.enter = { data, pointer, serial, surface, x, y in
            _ = unsafe data
            _ = unsafe pointer
            _ = serial
            _ = unsafe surface
            _ = x
            _ = y
        }
        unsafe callbacks.leave = { data, pointer, serial, surface in
            _ = unsafe data
            _ = unsafe pointer
            _ = serial
            _ = unsafe surface
        }
        unsafe callbacks.motion = { data, pointer, time, x, y in
            _ = unsafe data
            _ = unsafe pointer
            _ = time
            _ = x
            _ = y
        }
        unsafe callbacks.button = { data, pointer, serial, time, button, state in
            _ = unsafe data
            _ = unsafe pointer
            _ = serial
            _ = time
            _ = button
            _ = state
        }
        unsafe callbacks.data = nil
        #expect(unsafe callbacks.enter != nil)
        #expect(unsafe callbacks.button != nil)
    }
    @Test
    func pointerAxisCallbackSignaturesImportIntoSwift() {
        var callbacks = unsafe swl_pointer_listener_callbacks()
        unsafe callbacks.axis = { data, pointer, time, axis, value in
            _ = unsafe data
            _ = unsafe pointer
            _ = time
            _ = axis
            _ = value
        }
        unsafe callbacks.frame = { data, pointer in
            _ = unsafe data
            _ = unsafe pointer
        }
        unsafe callbacks.axis_source = { data, pointer, axisSource in
            _ = unsafe data
            _ = unsafe pointer
            _ = axisSource
        }
        unsafe callbacks.axis_stop = { data, pointer, time, axis in
            _ = unsafe data
            _ = unsafe pointer
            _ = time
            _ = axis
        }
        unsafe callbacks.axis_discrete = { data, pointer, axis, discrete in
            _ = unsafe data
            _ = unsafe pointer
            _ = axis
            _ = discrete
        }
        unsafe callbacks.axis_value120 = { data, pointer, axis, value120 in
            _ = unsafe data
            _ = unsafe pointer
            _ = axis
            _ = value120
        }
        unsafe callbacks.axis_relative_direction = { data, pointer, axis, direction in
            _ = unsafe data
            _ = unsafe pointer
            _ = axis
            _ = direction
        }
        unsafe callbacks.data = nil
        #expect(unsafe callbacks.axis != nil)
        #expect(unsafe callbacks.axis_relative_direction != nil)
    }
    @Test
    func keyboardListenerCallbackSignaturesImportIntoSwift() {
        var callbacks = unsafe swl_keyboard_listener_callbacks()
        unsafe callbacks.keymap = { data, keyboard, format, fd, size in
            _ = unsafe data
            _ = unsafe keyboard
            _ = format
            _ = fd
            _ = size
        }
        unsafe callbacks.enter = { data, keyboard, serial, surface, keys in
            _ = unsafe data
            _ = unsafe keyboard
            _ = serial
            _ = unsafe surface
            _ = unsafe keys
        }
        unsafe callbacks.leave = { data, keyboard, serial, surface in
            _ = unsafe data
            _ = unsafe keyboard
            _ = serial
            _ = unsafe surface
        }
        unsafe callbacks.key = { data, keyboard, serial, time, key, state in
            _ = unsafe data
            _ = unsafe keyboard
            _ = serial
            _ = time
            _ = key
            _ = state
        }
        unsafe callbacks.modifiers = { data, keyboard, serial, depressed, latched, locked, group in
            _ = unsafe data
            _ = unsafe keyboard
            _ = serial
            _ = depressed
            _ = latched
            _ = locked
            _ = group
        }
        unsafe callbacks.repeat_info = { data, keyboard, rate, delay in
            _ = unsafe data
            _ = unsafe keyboard
            _ = rate
            _ = delay
        }
        unsafe callbacks.data = nil
        #expect(unsafe callbacks.keymap != nil)
        #expect(unsafe callbacks.repeat_info != nil)
    }
    @Test
    func touchListenerCallbackSignaturesImportIntoSwift() {
        var callbacks = unsafe swl_touch_listener_callbacks()
        unsafe callbacks.down = { data, touch, serial, time, surface, id, x, y in
            _ = unsafe data
            _ = unsafe touch
            _ = serial
            _ = time
            _ = unsafe surface
            _ = id
            _ = x
            _ = y
        }
        unsafe callbacks.up = { data, touch, serial, time, id in
            _ = unsafe data
            _ = unsafe touch
            _ = serial
            _ = time
            _ = id
        }
        unsafe callbacks.motion = { data, touch, time, id, x, y in
            _ = unsafe data
            _ = unsafe touch
            _ = time
            _ = id
            _ = x
            _ = y
        }
        unsafe callbacks.frame = { data, touch in
            _ = unsafe data
            _ = unsafe touch
        }
        unsafe callbacks.cancel = { data, touch in
            _ = unsafe data
            _ = unsafe touch
        }
        unsafe callbacks.shape = { data, touch, id, major, minor in
            _ = unsafe data
            _ = unsafe touch
            _ = id
            _ = major
            _ = minor
        }
        unsafe callbacks.orientation = { data, touch, id, orientation in
            _ = unsafe data
            _ = unsafe touch
            _ = id
            _ = orientation
        }
        unsafe callbacks.data = nil
        #expect(unsafe callbacks.down != nil)
        #expect(unsafe callbacks.orientation != nil)
    }
}
