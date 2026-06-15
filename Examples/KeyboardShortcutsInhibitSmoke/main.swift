import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum KeyboardShortcutsInhibitSmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 128,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            log("feature: keyboard-shortcuts-inhibit")
            log("capability: \(availability(capabilities.keyboardShortcutsInhibit))")
            guard capabilities.keyboardShortcutsInhibit.isAvailable else {
                log("operation: inhibit skip")
                log("cleanup: pass")
                return
            }

            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Keyboard Shortcuts Inhibit Smoke",
                    appID: "wayland-client-kit-keyboard-shortcuts-inhibit-smoke",
                    initialWidth: 420,
                    initialHeight: 220,
                    closeRequestPolicy: .requestOnly
                )
            )
            try await window.show(draw)
            log("operation: waiting-for-seat")

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await consumeDisplayEvents(display.events, window: window) }
                group.addTask { try await consumeInputEvents(display.inputEvents, window: window) }
                if let seconds = options.autoCloseSeconds {
                    group.addTask {
                        try await Task.sleep(for: .seconds(seconds))
                        await window.close()
                    }
                }

                _ = try await group.next()
                group.cancelAll()
            }
            log("cleanup: pass")
        }
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        window: Window
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == window.id:
                try await window.redraw(draw)
            case .windowCloseRequested(let windowID) where windowID == window.id:
                await window.close()
            case .windowClosed(let windowID) where windowID == window.id:
                return
            case .diagnostic(let diagnostic):
                log("diagnostic \(diagnostic)")
            default:
                break
            }
        }
    }

    nonisolated private static func consumeInputEvents(
        _ events: InputEvents,
        window: Window
    ) async throws {
        var attemptedSeats = Set<SeatID>()
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard event.windowID == window.id else { continue }
            guard attemptedSeats.insert(event.seatID).inserted else { continue }

            await inhibit(window: window, seatID: event.seatID)
            await window.close()
            return
        }
    }

    nonisolated private static func inhibit(window: Window, seatID: SeatID) async {
        do {
            let inhibitor = try await window.inhibitKeyboardShortcuts(seatID: seatID)
            log("operation: inhibit pass id=\(inhibitor.id) seat=\(seatID)")
            try await inhibitor.destroy()
            log("operation: destroy pass")
        } catch {
            log("operation: inhibit failed seat=\(seatID) error=\(error)")
        }
    }

    nonisolated private static func draw(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let blue = UInt32((x * 255) / max(Int(frame.width), 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: x] = 0x0020_2000 | (green << 8) | blue
            }
        }
    }

    nonisolated private static func availability(_ availability: ProtocolAvailability) -> String {
        switch availability {
        case .available(let version):
            "available version=\(version)"
        case .unavailable:
            "unavailable"
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[KeyboardShortcutsInhibitSmoke] \(message)")
    }
}
