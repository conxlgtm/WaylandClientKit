import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum PointerGesturesSmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 256,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            log("feature: pointer-gestures")
            log("capability: \(availability(capabilities.pointerGestures))")
            guard capabilities.pointerGestures.isAvailable else {
                log("operation: subscribe skip")
                log("cleanup: pass")
                return
            }

            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Pointer Gestures Smoke",
                    appID: "wayland-client-kit-pointer-gestures-smoke",
                    initialWidth: 360,
                    initialHeight: 220,
                    closeRequestPolicy: .requestOnly
                )
            )
            try await window.show(draw)

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await consumeDisplayEvents(display.events, window: window) }
                group.addTask { try await consumeInputEvents(display.inputEvents, display: display, window: window) }
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
        display: WaylandDisplay,
        window: Window
    ) async throws {
        var subscribedSeats = Set<SeatID>()
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard event.windowID == window.id else { continue }
            if subscribedSeats.insert(event.seatID).inserted {
                await subscribe(display: display, seatID: event.seatID)
            }

            if case .pointer(.gesture(let gesture)) = event.kind {
                log("gesture seat=\(event.seatID) target=\(event.target) \(gesture)")
            }
        }
    }

    nonisolated private static func subscribe(display: WaylandDisplay, seatID: SeatID) async {
        do {
            let subscription = try await display.pointerGestures(seatID: seatID)
            log(
                "operation: subscribe pass id=\(subscription.id) "
                    + "seat=\(seatID) version=\(subscription.version)"
            )
        } catch {
            log("operation: subscribe failed seat=\(seatID) error=\(error)")
        }
    }

    nonisolated private static func draw(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let shade = UInt32((x + row) & 0x7F)
                unsafe pixels[unchecked: x] = 0x0018_1830 | (shade << 16) | shade
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
        print("[PointerGesturesSmoke] \(message)")
    }
}
