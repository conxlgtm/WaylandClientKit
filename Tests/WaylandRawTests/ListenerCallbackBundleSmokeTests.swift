import CWaylandProtocols
import Testing

@Suite
struct ListenerCallbackBundleSmokeTests {
    @Test
    func proxyVersionShimImportsIntoSwift() {
        let getVersion = swl_proxy_get_version

        #expect(MemoryLayout.size(ofValue: getVersion) > 0)
    }

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

    @Test
    func seatListenerCallbackSignaturesImportIntoSwift() {
        var callbacks = swl_seat_listener_callbacks()

        callbacks.capabilities = { data, seat, capabilities in
            _ = data
            _ = seat
            _ = capabilities
        }
        callbacks.name = { data, seat, name in
            _ = data
            _ = seat
            _ = name
        }
        callbacks.data = nil

        #expect(callbacks.capabilities != nil)
        #expect(callbacks.name != nil)
    }

    @Test
    func pointerListenerCallbackSignaturesImportIntoSwift() {
        var callbacks = swl_pointer_listener_callbacks()

        callbacks.enter = { data, pointer, serial, surface, x, y in
            _ = data
            _ = pointer
            _ = serial
            _ = surface
            _ = x
            _ = y
        }
        callbacks.leave = { data, pointer, serial, surface in
            _ = data
            _ = pointer
            _ = serial
            _ = surface
        }
        callbacks.motion = { data, pointer, time, x, y in
            _ = data
            _ = pointer
            _ = time
            _ = x
            _ = y
        }
        callbacks.button = { data, pointer, serial, time, button, state in
            _ = data
            _ = pointer
            _ = serial
            _ = time
            _ = button
            _ = state
        }
        callbacks.data = nil

        #expect(callbacks.enter != nil)
        #expect(callbacks.button != nil)
    }

    @Test
    func pointerAxisCallbackSignaturesImportIntoSwift() {
        var callbacks = swl_pointer_listener_callbacks()

        callbacks.axis = { data, pointer, time, axis, value in
            _ = data
            _ = pointer
            _ = time
            _ = axis
            _ = value
        }
        callbacks.frame = { data, pointer in
            _ = data
            _ = pointer
        }
        callbacks.axis_source = { data, pointer, axisSource in
            _ = data
            _ = pointer
            _ = axisSource
        }
        callbacks.axis_stop = { data, pointer, time, axis in
            _ = data
            _ = pointer
            _ = time
            _ = axis
        }
        callbacks.axis_discrete = { data, pointer, axis, discrete in
            _ = data
            _ = pointer
            _ = axis
            _ = discrete
        }
        callbacks.axis_value120 = { data, pointer, axis, value120 in
            _ = data
            _ = pointer
            _ = axis
            _ = value120
        }
        callbacks.axis_relative_direction = { data, pointer, axis, direction in
            _ = data
            _ = pointer
            _ = axis
            _ = direction
        }
        callbacks.data = nil

        #expect(callbacks.axis != nil)
        #expect(callbacks.axis_relative_direction != nil)
    }

    @Test
    func keyboardListenerCallbackSignaturesImportIntoSwift() {
        var callbacks = swl_keyboard_listener_callbacks()

        callbacks.keymap = { data, keyboard, format, fd, size in
            _ = data
            _ = keyboard
            _ = format
            _ = fd
            _ = size
        }
        callbacks.enter = { data, keyboard, serial, surface, keys in
            _ = data
            _ = keyboard
            _ = serial
            _ = surface
            _ = keys
        }
        callbacks.leave = { data, keyboard, serial, surface in
            _ = data
            _ = keyboard
            _ = serial
            _ = surface
        }
        callbacks.key = { data, keyboard, serial, time, key, state in
            _ = data
            _ = keyboard
            _ = serial
            _ = time
            _ = key
            _ = state
        }
        callbacks.modifiers = { data, keyboard, serial, depressed, latched, locked, group in
            _ = data
            _ = keyboard
            _ = serial
            _ = depressed
            _ = latched
            _ = locked
            _ = group
        }
        callbacks.repeat_info = { data, keyboard, rate, delay in
            _ = data
            _ = keyboard
            _ = rate
            _ = delay
        }
        callbacks.data = nil

        #expect(callbacks.keymap != nil)
        #expect(callbacks.repeat_info != nil)
    }

    @Test
    func touchListenerCallbackSignaturesImportIntoSwift() {
        var callbacks = swl_touch_listener_callbacks()

        callbacks.down = { data, touch, serial, time, surface, id, x, y in
            _ = data
            _ = touch
            _ = serial
            _ = time
            _ = surface
            _ = id
            _ = x
            _ = y
        }
        callbacks.up = { data, touch, serial, time, id in
            _ = data
            _ = touch
            _ = serial
            _ = time
            _ = id
        }
        callbacks.motion = { data, touch, time, id, x, y in
            _ = data
            _ = touch
            _ = time
            _ = id
            _ = x
            _ = y
        }
        callbacks.frame = { data, touch in
            _ = data
            _ = touch
        }
        callbacks.cancel = { data, touch in
            _ = data
            _ = touch
        }
        callbacks.shape = { data, touch, id, major, minor in
            _ = data
            _ = touch
            _ = id
            _ = major
            _ = minor
        }
        callbacks.orientation = { data, touch, id, orientation in
            _ = data
            _ = touch
            _ = id
            _ = orientation
        }
        callbacks.data = nil

        #expect(callbacks.down != nil)
        #expect(callbacks.orientation != nil)
    }
}
