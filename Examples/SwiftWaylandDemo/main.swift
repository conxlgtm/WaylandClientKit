import Foundation
import WaylandClient

@main
enum SwiftWaylandDemo {
    static func main() async throws {
        try await WaylandDisplay.withConnection { display in
            let window = try await display.createTopLevelWindow()
            var demoState = DemoState()

            let initialState = demoState
            try await window.show { frame in
                drawDemoFrame(frame, state: initialState)
            }

            try await runEventLoop(
                events: display.events,
                window: window,
                demoState: &demoState
            )
        }
    }

    nonisolated private static func runEventLoop(
        events: DisplayEvents,
        window: Window,
        demoState: inout DemoState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while let event = try await iterator.next() {
            guard !(try await handle(event, window: window, demoState: &demoState)) else {
                return
            }
        }
    }

    nonisolated private static func handle(
        _ event: DisplayEvent,
        window: Window,
        demoState: inout DemoState
    ) async throws -> Bool {
        switch event {
        case .input(let inputEvent):
            demoState.handle(inputEvent, focusedWindowID: window.id)
            if demoState.consumeNeedsRedraw() {
                try await window.requestRedraw()
            }
        case .diagnostic(let diagnostic):
            DemoLog.write("display diagnostic \(diagnostic)")
        case .redrawRequested(let windowID):
            guard windowID == window.id else { return false }
            let redrawState = demoState
            try await window.redraw { frame in
                drawDemoFrame(frame, state: redrawState)
            }
        case .popupRedrawRequested:
            break
        case .windowCloseRequested(let windowID):
            guard windowID == window.id else { return false }
            await window.close()
        case .windowClosed(let windowID):
            return windowID == window.id
        case .popupDismissed, .popupClosed:
            break
        }

        return false
    }

    nonisolated private static func drawDemoFrame(
        _ frame: borrowing SoftwareFrame,
        state: DemoState
    ) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let red = UInt32((x * 255) / max(Int(frame.width), 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                let blue = UInt32(0x80)
                pixels[unchecked: x] = (red << 16) | (green << 8) | blue
            }

            drawPointerMarker(
                row: row,
                pixels: &pixels,
                frameHeight: Int(frame.height),
                geometry: frame.geometry,
                state: state
            )
        }
    }

    nonisolated private static func drawPointerMarker(
        row: Int,
        pixels: inout MutableSpan<UInt32>,
        frameHeight: Int,
        geometry: SoftwareFrameGeometry,
        state: DemoState
    ) {
        guard case .inside(let location, let isPressed) = state.pointer else {
            return
        }

        let point = geometry.bufferPixelPoint(logicalX: location.x, logicalY: location.y)
        let markerX = min(max(point.x, 0), pixels.count - 1)
        let markerY = min(max(point.y, 0), frameHeight - 1)
        let radius = 5
        guard abs(row - markerY) <= radius else { return }

        let color: UInt32 = isPressed ? 0x00FF_2020 : 0x00FF_FFFF
        let startX = max(markerX - radius, 0)
        let endX = min(markerX + radius, pixels.count - 1)
        guard startX <= endX else { return }

        for x in startX...endX {
            pixels[unchecked: x] = color
        }
    }
}

private struct DemoState {
    var pointer = PointerMarkerState.outside
    private var needsRedraw = false

    nonisolated mutating func handle(_ event: InputEvent, focusedWindowID: WindowID) {
        switch event.kind {
        case .seat(let seat):
            handleSeat(seat, seatID: event.seatID)
        case .diagnostic(let diagnostic):
            DemoLog.write(
                "input diagnostic seat=\(event.seatID) operation=\(diagnostic.operation) "
                    + "message=\(diagnostic.message)"
            )
        case .pointer(let pointer):
            guard event.windowID == focusedWindowID else { return }
            handlePointer(pointer)
        case .keyboard(let keyboard):
            guard acceptsWindowOrDisplayTarget(event.target, focusedWindowID) else { return }
            handleKeyboard(keyboard, seatID: event.seatID)
        case .touch(let touch):
            guard acceptsWindowOrDisplayTarget(event.target, focusedWindowID) else { return }
            handleTouch(touch, seatID: event.seatID)
        }
    }

    nonisolated private func acceptsWindowOrDisplayTarget(
        _ target: InputEventTarget,
        _ focusedWindowID: WindowID
    ) -> Bool {
        switch target {
        case .surface(let surface):
            surface.windowID == focusedWindowID
        case .display, .focusless:
            true
        case .unmanagedSurface:
            false
        }
    }

    nonisolated mutating func consumeNeedsRedraw() -> Bool {
        defer { needsRedraw = false }
        return needsRedraw
    }

    nonisolated private mutating func handleSeat(_ event: SeatEvent, seatID: SeatID) {
        switch event {
        case .changed(let snapshot):
            DemoLog.write(
                "seat \(seatID) capabilities advertised=\(snapshot.advertisedCapabilities) "
                    + "active=\(snapshot.activeCapabilities) "
                    + "name=\(snapshot.name?.description ?? "?")"
            )
        case .removed:
            DemoLog.write("seat \(seatID) removed")
        }
    }

    nonisolated private mutating func handlePointer(_ event: PointerEvent) {
        switch event {
        case .entered(let location, let serial):
            pointer = .inside(location: location, pressed: false)
            needsRedraw = true
            DemoLog.write("pointer entered serial=\(serial) x=\(location.x) y=\(location.y)")
        case .left(let serial):
            pointer = .outside
            needsRedraw = true
            DemoLog.write("pointer left serial=\(serial)")
        case .moved(let location, _):
            guard case .inside(_, let pressed) = pointer else { return }
            pointer = .inside(location: location, pressed: pressed)
            needsRedraw = true
        case .button(let button):
            guard case .inside(let location, _) = pointer else { return }
            pointer = .inside(location: location, pressed: button.state == .pressed)
            needsRedraw = true
            DemoLog.write(
                "pointer button serial=\(button.serial) button=\(button.button) "
                    + "state=\(button.state.rawValue)"
            )
        case .axis(let axis):
            DemoLog.write("pointer axis \(axis)")
        }
    }

    nonisolated private func handleKeyboard(_ event: KeyboardEvent, seatID: SeatID) {
        switch event {
        case .raw(let rawEvent):
            handleRawKeyboard(rawEvent, seatID: seatID)
        case .interpreted(let interpretedEvent):
            handleInterpretedKeyboard(interpretedEvent, seatID: seatID)
        }
    }

    nonisolated private func handleRawKeyboard(_ event: RawKeyboardEvent, seatID: SeatID) {
        switch event {
        case .keymapChanged(let keymap):
            DemoLog.write(
                "keyboard keymap seat=\(seatID) format=\(keymap.format.rawValue) "
                    + "size=\(keymap.size)"
            )
        case .entered(let serial, let pressedKeys):
            DemoLog.write("keyboard entered serial=\(serial) pressed=\(pressedKeys)")
        case .left(let serial):
            DemoLog.write("keyboard left serial=\(serial)")
        case .key(let key):
            DemoLog.write(
                "keyboard key seat=\(seatID) serial=\(key.serial) "
                    + "rawKeycode=\(key.rawKeycode) state=\(key.state.rawValue)"
            )
        case .modifiers(let modifiers):
            DemoLog.write(
                "keyboard modifiers serial=\(modifiers.serial) "
                    + "depressed=\(modifiers.depressed) latched=\(modifiers.latched) "
                    + "locked=\(modifiers.locked) group=\(modifiers.group)"
            )
        case .repeatInfo(let repeatInfo):
            DemoLog.write(
                "keyboard repeat policy=\(repeatPolicyDescription(repeatInfo))"
            )
        }
    }

    nonisolated private func handleInterpretedKeyboard(
        _ event: InterpretedKeyboardEvent,
        seatID: SeatID
    ) {
        switch event {
        case .keymap(let keymap):
            DemoLog.write(
                "keyboard interpreted keymap seat=\(seatID) "
                    + "format=\(keymap.format.rawValue) size=\(keymap.size)"
            )
        case .key(let key):
            let keysymName = key.keysymName ?? "?"
            var message =
                "keyboard interpreted key seat=\(seatID) serial=\(key.serial) "
                + "rawKeycode=\(key.rawKeycode) xkbKeycode=\(key.xkbKeycode) "
                + "state=\(key.state.rawValue) keysym=\(keysymName)"
            if DemoLog.logsTextInput, let utf8 = key.utf8 {
                message += " utf8=\(utf8)"
            }
            if DemoLog.logsTextInput {
                message += " text=\(keyboardTextDescription(key.text))"
            }
            DemoLog.write(message)
        case .modifiers(let modifiers):
            DemoLog.write(
                "keyboard interpreted modifiers seat=\(seatID) serial=\(modifiers.serial) "
                    + "depressed=\(modifiers.depressed) latched=\(modifiers.latched) "
                    + "locked=\(modifiers.locked) group=\(modifiers.group) "
                    + "changed=\(modifiers.changedComponents.rawValue)"
            )
        case .repeatInfo(let repeatInfo):
            DemoLog.write(
                "keyboard interpreted repeat seat=\(seatID) "
                    + "policy=\(repeatPolicyDescription(repeatInfo))"
            )
        case .unavailable(let unavailable):
            DemoLog.write(
                "keyboard interpretation unavailable seat=\(seatID) "
                    + "reason=\(unavailable.reason)"
            )
        }
    }

    nonisolated private func repeatPolicyDescription(_ policy: KeyboardRepeatPolicy) -> String {
        switch policy {
        case .disabled:
            "disabled"
        case .enabled(let rate, let delay):
            "enabled rate=\(rate.rawValue) delay=\(delay.rawValue)"
        }
    }

    nonisolated private func keyboardTextDescription(_ result: KeyboardTextResult) -> String {
        switch result {
        case .none:
            "none"
        case .composing(let progress):
            "composing startedBy=\(progress.startedByName ?? "?")"
        case .committed(let commit):
            "committed source=\(commit.source) string=\(commit.string)"
        case .cancelled(let cancellation):
            if let fallback = cancellation.fallbackCommit {
                "cancelled key=\(cancellation.cancellingKeysymName ?? "?") "
                    + "fallback=\(fallback.string)"
            } else {
                "cancelled key=\(cancellation.cancellingKeysymName ?? "?")"
            }
        }
    }

    nonisolated private func handleTouch(_ event: TouchEvent, seatID: SeatID) {
        switch event {
        case .down(let down):
            DemoLog.write(
                "touch down seat=\(seatID) serial=\(down.serial) id=\(down.id) "
                    + "x=\(down.location.x) y=\(down.location.y)"
            )
        case .up(let up):
            DemoLog.write("touch up seat=\(seatID) serial=\(up.serial) id=\(up.id)")
        case .motion(let motion):
            DemoLog.write(
                "touch motion seat=\(seatID) id=\(motion.id) "
                    + "x=\(motion.location.x) y=\(motion.location.y)"
            )
        case .frame:
            DemoLog.write("touch frame seat=\(seatID)")
        case .cancel:
            DemoLog.write("touch cancel seat=\(seatID)")
        case .shape(let shape):
            DemoLog.write(
                "touch shape seat=\(seatID) id=\(shape.id) "
                    + "major=\(shape.major) minor=\(shape.minor)"
            )
        case .orientation(let orientation):
            DemoLog.write(
                "touch orientation seat=\(seatID) id=\(orientation.id) "
                    + "orientation=\(orientation.orientation)"
            )
        }
    }
}

private enum PointerMarkerState {
    case outside
    case inside(location: PointerLocation, pressed: Bool)
}

private enum DemoLog {
    nonisolated static let logsTextInput = CommandLine.arguments.contains("--verbose-text")

    nonisolated static func write(_ message: String) {
        FileHandle.standardOutput.write(Data((message + "\n").utf8))
    }
}
