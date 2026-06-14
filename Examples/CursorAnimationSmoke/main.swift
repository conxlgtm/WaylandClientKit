import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum CursorAnimationSmoke {
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
        log("feature: cursor-animation")
        log("capability: custom-image-cursor available")
        let window = try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: "WaylandClientKit Cursor Animation Smoke",
                appID: "wayland-client-kit-cursor-animation-smoke",
                initialWidth: 360,
                initialHeight: 220,
                closeRequestPolicy: .requestOnly
            )
        )
        try await show(window)

        let animatedCursor = try animatedTestCursor()
        let staticCursor = try PointerCursor.image(staticCursorImage())

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await consumeDisplayEvents(display.events, window: window) }
            group.addTask {
                try await runCursorSequence(
                    display: display,
                    window: window,
                    animatedCursor: animatedCursor,
                    staticCursor: staticCursor,
                    options: options
                )
            }
            _ = try await group.next()
            group.cancelAll()
        }

        if options.printSummary {
            log("cursor-animation summary animated=pass replacements=theme,hidden,static,default")
        }
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

    nonisolated private static func runCursorSequence(
        display: WaylandDisplay,
        window: Window,
        animatedCursor: PointerCursor,
        staticCursor: PointerCursor,
        options: ExampleRunOptions
    ) async throws {
        try await setCursor(animatedCursor, display: display, operation: "set-animated")
        try await pause(options)
        try await setCursor(.defaultArrow, display: display, operation: "replace-with-theme")
        try await pause(options)
        try await setCursor(.hidden, display: display, operation: "replace-with-hidden")
        try await pause(options)
        try await setCursor(staticCursor, display: display, operation: "replace-with-static")
        try await pause(options)
        try await setCursor(.defaultArrow, display: display, operation: "replace-with-default")
        try await pause(options)
        try await setCursor(
            animatedCursor, display: display, operation: "set-animated-before-close")
        await window.close()
    }

    nonisolated private static func setCursor(
        _ cursor: PointerCursor,
        display: WaylandDisplay,
        operation: String
    ) async throws {
        _ = try await display.setPointerCursor(cursor)
        log("operation: \(operation) pass")
    }

    nonisolated private static func pause(_ options: ExampleRunOptions) async throws {
        let seconds = min(options.autoCloseSeconds ?? 1, 1)
        try await Task.sleep(for: .milliseconds(max(seconds * 200, 100)))
    }

    nonisolated private static func animatedTestCursor() throws -> PointerCursor {
        let frames = try [
            PointerCursorFrame(image: frameImage(fill: 0x0000_88FF), duration: .milliseconds(120)),
            PointerCursorFrame(image: frameImage(fill: 0x0000_CC66), duration: .milliseconds(120)),
            PointerCursorFrame(image: frameImage(fill: 0x00FF_D040), duration: .milliseconds(120)),
        ]
        return try .animated(AnimatedPointerCursor(frames: frames))
    }

    nonisolated private static func staticCursorImage() throws -> PointerCursorImage {
        try frameImage(fill: 0x00FF_FFFF)
    }

    nonisolated private static func frameImage(fill: UInt32) throws -> PointerCursorImage {
        let size = try PositivePixelSize(width: 32, height: 32)
        var pixels = Array(repeating: UInt32(0), count: 32 * 32)
        for y in 0..<32 {
            for x in 0..<32 {
                let index = (y * 32) + x
                if x == 0 || y == 0 || x == y || x < 8 && y < 24 {
                    pixels[index] = fill
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
                let red = UInt32((x * 255) / max(Int(frame.width), 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: x] = (red << 16) | (green << 8) | 0x44
            }
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[CursorAnimationSmoke] \(message)")
    }
}
