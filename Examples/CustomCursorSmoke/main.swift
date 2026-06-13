import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum CustomCursorSmoke {
    nonisolated private static let leftButton = PointerButtonCode(rawValue: 0x110)
    nonisolated private static let rightButton = PointerButtonCode(rawValue: 0x111)
    nonisolated private static let middleButton = PointerButtonCode(rawValue: 0x112)

    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())
        try await WaylandDisplay.withConnection { display in
            try await run(display: display, options: options)
        }
    }

    nonisolated private static func run(
        display: WaylandDisplay,
        options: ExampleRunOptions
    ) async throws {
        log("feature: custom-cursor-image")
        log("capability: pointer cursor image surface")
        let window = try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: "WaylandClientKit Custom Cursor Smoke",
                appID: "wayland-client-kit-custom-cursor-smoke",
                initialWidth: 360,
                initialHeight: 220,
                closeRequestPolicy: .requestOnly
            )
        )
        try await show(window)

        let customCursor = try PointerCursor.image(makeCursorImage())
        try await display.setPointerCursor(customCursor)
        log("operation: set-custom-cursor pass")
        log("initial custom cursor applied")

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await consumeDisplayEvents(display.events, window: window) }
            group.addTask {
                try await consumeInputEvents(
                    display.inputEvents,
                    window: window,
                    display: display,
                    customCursor: customCursor
                )
            }
            if let seconds = options.autoCloseSeconds {
                group.addTask {
                    try await Task.sleep(for: .seconds(seconds))
                    await window.close()
                }
            }
            _ = try await group.next()
            group.cancelAll()
        }
        if options.printSummary {
            log("custom-cursor summary customImage=set hidden=manual themeDefault=manual")
        }
        log("result: pass")
        log("cleanup: pass")
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        window: Window
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == window.id:
                try await redraw(window)
            case .windowCloseRequested(let windowID) where windowID == window.id:
                await window.close()
            case .windowClosed(let windowID) where windowID == window.id:
                return
            case .diagnostic(let diagnostic):
                log("display diagnostic \(diagnostic)")
            default:
                break
            }
        }
    }

    nonisolated private static func consumeInputEvents(
        _ events: InputEvents,
        window: Window,
        display: WaylandDisplay,
        customCursor: PointerCursor
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard event.windowID == window.id else { continue }

            switch event.kind {
            case .pointer(.entered(let location, let serial)):
                log(
                    "pointer entered seat=\(event.seatID) serial=\(serial) "
                        + "location=\(location.x),\(location.y)"
                )
            case .pointer(.button(let button)) where button.state == .pressed:
                try await updateCursor(for: button, display: display, customCursor: customCursor)
            case .diagnostic(let diagnostic):
                log("input diagnostic \(diagnostic)")
            default:
                break
            }
        }
    }

    nonisolated private static func updateCursor(
        for button: PointerButtonEvent,
        display: WaylandDisplay,
        customCursor: PointerCursor
    ) async throws {
        let cursor: PointerCursor
        let label: String
        switch button.button {
        case leftButton:
            cursor = customCursor
            label = "custom image"
        case rightButton:
            cursor = .hidden
            label = "hidden"
        case middleButton:
            cursor = .defaultArrow
            label = "theme default"
        default:
            return
        }

        let results = try await display.setPointerCursor(cursor)
        log("operation: set-cursor pass")
        log("set cursor=\(label) results=\(results)")
    }

    nonisolated private static func makeCursorImage() throws -> PointerCursorImage {
        let size = try PositivePixelSize(width: 32, height: 32)
        var pixels = Array(repeating: UInt32(0), count: 32 * 32)
        for y in 0..<32 {
            for x in 0..<32 {
                let index = (y * 32) + x
                if x == y {
                    pixels[index] = 0x00FF_FFFF
                } else if x == 0 || y == 0 {
                    pixels[index] = 0x00FF_FFFF
                } else if x < 16, y < 16 {
                    pixels[index] = 0x0000_99FF
                }
            }
        }

        return try PointerCursorImage(size: size, hotspotX: 0, hotspotY: 0, pixels: pixels)
    }

    nonisolated private static func show(_ window: Window) async throws {
        try await window.show { frame in
            draw(frame)
        }
    }

    nonisolated private static func redraw(_ window: Window) async throws {
        try await window.redraw { frame in
            draw(frame)
        }
    }

    nonisolated private static func draw(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let blue = UInt32((x * 255) / max(Int(frame.width), 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: x] = 0x220000 | (green << 8) | blue
            }
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[CustomCursorSmoke] \(message)")
    }
}
