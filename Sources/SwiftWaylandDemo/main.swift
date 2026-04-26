import Foundation
import WaylandClient

@main
enum SwiftWaylandDemo {
    static func main() throws {
        let session = try DisplaySession.connect()
        let window = try session.createTopLevelWindow()
        var demoState = DemoState()

        try window.show { frame in
            drawDemoFrame(frame, state: demoState)
        }

        while !window.isClosed {
            try session.pumpEvents(timeoutMilliseconds: 16)

            for event in session.drainInputEvents() {
                demoState.handle(event, focusedWindowID: window.id)
            }

            if demoState.consumeNeedsRedraw() || window.needsRedraw {
                try window.redraw { frame in
                    drawDemoFrame(frame, state: demoState)
                }
            }
        }
    }

    private static func drawDemoFrame(_ frame: SoftwareFrame, state: DemoState) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let red = UInt32((x * 255) / max(Int(frame.width), 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                let blue = UInt32(0x80)
                pixels[unchecked: x] = (red << 16) | (green << 8) | blue
            }

            drawPointerMarker(row: row, pixels: &pixels, state: state)
        }
    }

    private static func drawPointerMarker(
        row: Int,
        pixels: inout MutableSpan<UInt32>,
        state: DemoState
    ) {
        guard
            state.pointerInside,
            let location = state.pointerLocation
        else {
            return
        }

        let markerX = Int(location.x.rounded())
        let markerY = Int(location.y.rounded())
        let radius = 5
        guard abs(row - markerY) <= radius else { return }

        let color: UInt32 = state.pointerPressed ? 0x00FF_2020 : 0x00FF_FFFF
        let startX = max(markerX - radius, 0)
        let endX = min(markerX + radius, pixels.count - 1)
        guard startX <= endX else { return }

        for x in startX...endX {
            pixels[unchecked: x] = color
        }
    }
}

private struct DemoState {
    var pointerLocation: PointerLocation?
    var pointerInside = false
    var pointerPressed = false
    private var needsRedraw = false

    mutating func handle(_ event: InputEvent, focusedWindowID: WindowID) {
        switch event.kind {
        case .seat(let seat):
            handleSeat(seat, seatID: event.seatID)
        case .pointer(let pointer):
            guard event.windowID == focusedWindowID else { return }
            handlePointer(pointer)
        case .keyboard(let keyboard):
            guard event.windowID == nil || event.windowID == focusedWindowID else {
                return
            }
            handleKeyboard(keyboard, seatID: event.seatID)
        }
    }

    mutating func consumeNeedsRedraw() -> Bool {
        defer { needsRedraw = false }
        return needsRedraw
    }

    private mutating func handleSeat(_ event: SeatEvent, seatID: SeatID) {
        switch event {
        case .changed(let snapshot):
            DemoLog.write(
                "seat \(seatID) capabilities advertised=\(snapshot.advertisedCapabilities) "
                    + "active=\(snapshot.activeCapabilities) name=\(snapshot.name ?? "?")"
            )
        case .removed:
            DemoLog.write("seat \(seatID) removed")
        }
    }

    private mutating func handlePointer(_ event: PointerEvent) {
        switch event {
        case .entered(let location, let serial):
            pointerInside = true
            pointerLocation = location
            needsRedraw = true
            DemoLog.write("pointer entered serial=\(serial) x=\(location.x) y=\(location.y)")
        case .left(let serial):
            pointerInside = false
            pointerLocation = nil
            needsRedraw = true
            DemoLog.write("pointer left serial=\(serial)")
        case .moved(let location, _):
            pointerLocation = location
            needsRedraw = true
        case .button(let button):
            pointerPressed = button.state == .pressed
            needsRedraw = true
            DemoLog.write(
                "pointer button serial=\(button.serial) button=\(button.button) "
                    + "state=\(button.state.rawValue)"
            )
        case .axis(let axis):
            DemoLog.write("pointer axis \(axis)")
        }
    }

    private func handleKeyboard(_ event: KeyboardEvent, seatID: SeatID) {
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
            DemoLog.write("keyboard repeat rate=\(repeatInfo.rate) delay=\(repeatInfo.delay)")
        }
    }
}

private enum DemoLog {
    static func write(_ message: String) {
        FileHandle.standardOutput.write(Data((message + "\n").utf8))
    }
}
