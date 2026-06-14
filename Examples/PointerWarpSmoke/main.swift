import WaylandClient
import WaylandExampleSupport

@main
enum PointerWarpSmoke {
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
            try await run(display: display, options: options)
        }
    }

    nonisolated private static func run(
        display: WaylandDisplay,
        options: ExampleRunOptions
    ) async throws {
        let capabilities = try await display.capabilities()
        log("feature: pointer-warp")
        log("capability: pointer-warp \(capabilities.pointerWarp)")

        guard capabilities.pointerWarp.isAvailable else {
            log("operation: request-warp skip(protocol-unavailable)")
            log("cleanup: pass")
            return
        }

        let state = PointerWarpSmokeState()
        let window = try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: "WaylandClientKit Pointer Warp Smoke",
                appID: "wayland-client-kit-pointer-warp-smoke",
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
                    state: state
                )
            }
            group.addTask {
                try await Task.sleep(for: .seconds(options.autoCloseSeconds ?? 3))
                await window.close()
            }
            _ = try await group.next()
            group.cancelAll()
        }

        if !(await state.didAttemptWarp) {
            log("operation: request-warp skip(no-pointer-enter)")
        }
        if options.printSummary {
            let outcome = await state.summary
            log("pointer-warp summary requested=\(outcome)")
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

    nonisolated private static func consumeInputEvents(
        _ events: InputEvents,
        window: Window,
        state: PointerWarpSmokeState
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
                if await state.beginWarpAttempt() {
                    await requestWarp(window: window, seatID: event.seatID, serial: serial)
                }
            default:
                break
            }
        }
    }

    nonisolated private static func requestWarp(
        window: Window,
        seatID: SeatID,
        serial: InputSerial
    ) async {
        do {
            try await window.requestPointerWarp(
                seatID: seatID,
                position: LogicalOffset(x: 32, y: 32),
                serial: serial
            )
            log("operation: request-warp pass")
        } catch {
            log("operation: request-warp failed(\(error))")
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
                unsafe pixels[unchecked: x] = (red << 16) | (green << 8) | 0x88
            }
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[PointerWarpSmoke] \(message)")
    }
}

private actor PointerWarpSmokeState {
    private var attempted = false

    var didAttemptWarp: Bool {
        attempted
    }

    var summary: String {
        attempted ? "attempted" : "skipped"
    }

    func beginWarpAttempt() -> Bool {
        guard !attempted else { return false }

        attempted = true
        return true
    }
}
