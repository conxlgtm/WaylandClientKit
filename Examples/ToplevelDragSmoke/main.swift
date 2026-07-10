import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum ToplevelDragSmoke {
    nonisolated private static let leftButton = PointerButtonCode(rawValue: 0x110)

    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.ToplevelDragSmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 128,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 64,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            log("feature: xdg-toplevel-drag")
            log("capability: \(availability(capabilities.xdgToplevelDrag))")
            guard capabilities.xdgToplevelDrag.isAvailable else {
                log("operation: attach skip")
                log("cleanup: pass")
                return
            }

            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Toplevel Drag Smoke",
                    appID: "wayland-client-kit-toplevel-drag-smoke",
                    initialWidth: 360,
                    initialHeight: 220,
                    closeRequestPolicy: .requestOnly
                )
            )
            try await window.show(draw)
            log("operation: waiting-for-live-button-serial")

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await consumeDisplayEvents(display.events, window: window) }
                group.addTask { try await consumeInputEvents(display.inputEvents, window: window) }
                group.addTask {
                    try await consumeDataTransferEvents(display.dataTransferEvents, window: window)
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
        var attempted = false
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard event.windowID == window.id else { continue }

            switch event.kind {
            case .pointer(.button(let button))
            where !attempted && button.state == .pressed && button.button == leftButton:
                attempted = true
                await startToplevelDrag(window: window, seatID: event.seatID, serial: button.serial)
            default:
                break
            }
        }
    }

    nonisolated private static func consumeDataTransferEvents(
        _ events: DataTransferEvents,
        window: Window
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            log("data-transfer event \(event)")
            if event.isSourceDragTerminal {
                await window.close()
                return
            }
        }
    }

    nonisolated private static func startToplevelDrag(
        window: Window,
        seatID: SeatID,
        serial: InputSerial
    ) async {
        do {
            let started = try await window.startToplevelDrag(
                source: try DragSourceConfiguration.data(
                    mimeType: .plainText,
                    Data("WaylandClientKit toplevel drag smoke".utf8),
                    actions: [.move]
                ),
                seatID: seatID,
                serial: serial,
                icon: .none
            )
            log(
                "operation: start-toplevel-drag pass source=\(started.source.identity) id=\(started.drag.id) seat=\(seatID) serial=\(serial)"
            )
        } catch {
            log("operation: start-toplevel-drag failed error=\(error)")
        }
    }

    nonisolated private static func draw(_ frame: borrowing SoftwareFrame) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let red = UInt32((x * 255) / max(Int(frame.width), 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: x] = (red << 16) | (green << 8) | 0x22
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
        print("[ToplevelDragSmoke] \(message)")
    }
}

extension DataTransferEvent {
    nonisolated fileprivate var isSourceDragTerminal: Bool {
        switch self {
        case .dragSourceCancelled,
            .dragSourceDropPerformed,
            .dragSourceFinished:
            true
        default:
            false
        }
    }
}
