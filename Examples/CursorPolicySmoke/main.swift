import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum CursorPolicySmoke {
    nonisolated private static let leftButton = PointerButtonCode(rawValue: 0x110)
    nonisolated private static let rightButton = PointerButtonCode(rawValue: 0x111)
    nonisolated private static let middleButton = PointerButtonCode(rawValue: 0x112)

    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())
        let cursorConfiguration = CursorConfiguration(
            scalePolicy: .matchFocusedOutput,
            fallbackCursor: .defaultArrow
        )

        try await WaylandDisplay.withConnection(
            cursorConfiguration: cursorConfiguration
        ) { display in
            try await run(
                display: display, options: options, cursorConfiguration: cursorConfiguration)
        }
    }

    nonisolated private static func run(
        display: WaylandDisplay,
        options: ExampleRunOptions,
        cursorConfiguration: CursorConfiguration
    ) async throws {
        let capabilities = try await display.capabilities()
        log("feature: cursor-policy")
        log("capability: cursor-shape \(capabilities.cursorShape)")
        log(
            "capabilities cursorShape=\(capabilities.cursorShape) "
                + "scalePolicy=\(cursorConfiguration.scalePolicy)"
        )
        log("operation: configure-scale-policy pass")

        let window = try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: "SwiftWayland Cursor Policy Smoke",
                appID: "swift-wayland-cursor-policy-smoke",
                initialWidth: 360,
                initialHeight: 220,
                closeRequestPolicy: .requestOnly
            )
        )
        try await show(window)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await consumeDisplayEvents(display.events, window: window) }
            group.addTask {
                try await consumeInputEvents(
                    display.inputEvents,
                    window: window,
                    display: display
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
            log("cursor-policy summary scalePolicy=matchFocusedOutput interactions=manual")
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
            case .windowOutputsChanged(let outputs) where outputs.windowID == window.id:
                log("window outputs=\(outputs.outputs)")
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
        display: WaylandDisplay
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
                try await updateCursor(for: button, display: display)
            case .diagnostic(let diagnostic):
                log("input diagnostic \(diagnostic)")
            default:
                break
            }
        }
    }

    nonisolated private static func updateCursor(
        for button: PointerButtonEvent,
        display: WaylandDisplay
    ) async throws {
        let cursor: PointerCursor
        switch button.button {
        case leftButton:
            cursor = .text
        case rightButton:
            cursor = .hidden
        case middleButton:
            cursor = .resizeLeftRight
        default:
            return
        }

        let results = try await display.setPointerCursor(cursor)
        log("operation: set-cursor pass")
        log("set cursor=\(cursor.name ?? "hidden") results=\(results)")
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
                unsafe pixels[unchecked: x] = 0x330000 | (green << 8) | blue
            }
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[CursorPolicySmoke] \(message)")
    }
}
