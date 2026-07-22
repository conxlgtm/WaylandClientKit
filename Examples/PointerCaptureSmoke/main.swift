import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum PointerCaptureSmoke {
    nonisolated private static let leftButton = PointerButtonCode(rawValue: 0x110)
    nonisolated private static let rightButton = PointerButtonCode(rawValue: 0x111)
    nonisolated private static let middleButton = PointerButtonCode(rawValue: 0x112)

    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())
        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.PointerCaptureSmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                eventCapacity: 64,
                inputEventCapacity: 256,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            try await run(display: display, options: options)
        }
    }

    nonisolated private static func run(
        display: WaylandDisplay,
        options: ExampleRunOptions
    ) async throws {
        let capabilities = try await display.capabilities()
        log("feature: pointer-capture")
        log("capability: relative-pointer \(capabilities.relativePointer)")
        log("capability: pointer-constraints \(capabilities.pointerConstraints)")
        log(
            "capabilities relativePointer=\(capabilities.relativePointer) "
                + "pointerConstraints=\(capabilities.pointerConstraints)"
        )
        log(
            "instructions: the visible cursor may pin inside the window after lock; "
                + "keep moving the mouse to prove relative motion"
        )
        log(
            "instructions: left-click locks, right-click confines, middle-click retries "
                + "relative-motion subscription, close or Alt-Tab releases compositor focus"
        )

        let window = try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: "WaylandClientKit Pointer Capture Smoke",
                appID: "wayland-client-kit-pointer-capture-smoke",
                initialWidth: 420,
                initialHeight: 240,
                closeRequestPolicy: .requestOnly
            )
        )
        try await show(window)

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
        if options.printSummary {
            log(
                "pointer-capture summary relativePointer=\(capabilities.relativePointer) "
                    + "pointerConstraints=\(capabilities.pointerConstraints) "
                    + "interactions=manual"
            )
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
        window: Window
    ) async throws {
        var relativePointerAttemptedSeats = Set<SeatID>()
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard event.windowID == window.id else { continue }

            switch event.kind {
            case .pointer(.entered(let location, let serial)):
                log(
                    "pointer entered seat=\(event.seatID) serial=\(serial) "
                        + "location=\(location.x),\(location.y)"
                )
                if relativePointerAttemptedSeats.insert(event.seatID).inserted {
                    await subscribeRelativePointer(
                        seatID: event.seatID,
                        window: window,
                        mode: "auto"
                    )
                }
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
                await subscribeRelativePointer(seatID: seatID, window: window, mode: "manual")
            case leftButton:
                let constraint = try await window.lockPointer(
                    seatID: seatID,
                    lifetime: .persistent
                )
                log("operation: lock-pointer pass")
                log("lock requested id=\(constraint.id) seat=\(seatID)")
            case rightButton:
                let constraint = try await window.confinePointer(
                    seatID: seatID,
                    lifetime: .persistent
                )
                log("operation: confine-pointer pass")
                log("confine requested id=\(constraint.id) seat=\(seatID)")
            default:
                break
            }
        } catch {
            log("operation: pointer-capture failed")
            log("pointer capture request failed \(error)")
        }
    }

    nonisolated private static func subscribeRelativePointer(
        seatID: SeatID,
        window: Window,
        mode: String
    ) async {
        do {
            let subscription = try await window.relativePointer(seatID: seatID)
            log("operation: relative-pointer pass")
            log("relative pointer \(mode)-subscribed id=\(subscription.id) seat=\(seatID)")
        } catch {
            log("operation: relative-pointer failed")
            log("relative pointer \(mode)-subscribe failed \(error)")
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
