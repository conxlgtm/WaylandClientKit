import Foundation
import WaylandClient

@main
enum PointerCaptureSmoke {
    nonisolated private static let leftButton = PointerButtonCode(rawValue: 0x110)
    nonisolated private static let rightButton = PointerButtonCode(rawValue: 0x111)
    nonisolated private static let middleButton = PointerButtonCode(rawValue: 0x112)

    static func main() async throws {
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
            log(
                "capabilities relativePointer=\(capabilities.relativePointer) "
                    + "pointerConstraints=\(capabilities.pointerConstraints)"
            )

            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "SwiftWayland Pointer Capture Smoke",
                    appID: "swift-wayland-pointer-capture-smoke",
                    initialWidth: 420,
                    initialHeight: 240,
                    closeRequestPolicy: .requestOnly
                )
            )
            try await show(window)

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await consumeDisplayEvents(display.events, window: window) }
                group.addTask { try await consumeInputEvents(display.inputEvents, window: window) }
                _ = try await group.next()
                group.cancelAll()
            }
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
        window: Window
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
                try await handleButton(button, seatID: event.seatID, window: window)
            case .pointer(.relativeMotion(let motion)):
                log(
                    "relative motion seat=\(event.seatID) time=\(motion.time) "
                        + "delta=\(motion.delta.dx),\(motion.delta.dy) "
                        + "unaccelerated=\(motion.unacceleratedDelta.dx),"
                        + "\(motion.unacceleratedDelta.dy)"
                )
            case .pointer(.constraintLifecycle(let lifecycleEvent)):
                log("constraint lifecycle seat=\(event.seatID) \(lifecycleEvent)")
            default:
                break
            }
        }
    }

    nonisolated private static func handleButton(
        _ button: PointerButtonEvent,
        seatID: SeatID,
        window: Window
    ) async throws {
        do {
            switch button.button {
            case middleButton:
                let subscription = try await window.relativePointer(seatID: seatID)
                log("relative pointer subscribed id=\(subscription.id) seat=\(seatID)")
            case leftButton:
                let constraint = try await window.lockPointer(
                    seatID: seatID,
                    lifetime: .persistent
                )
                log("lock requested id=\(constraint.id) seat=\(seatID)")
            case rightButton:
                let constraint = try await window.confinePointer(
                    seatID: seatID,
                    lifetime: .persistent
                )
                log("confine requested id=\(constraint.id) seat=\(seatID)")
            default:
                break
            }
        } catch {
            log("pointer capture request failed \(error)")
        }
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
        print("[PointerCaptureSmoke] \(message)")
    }
}
