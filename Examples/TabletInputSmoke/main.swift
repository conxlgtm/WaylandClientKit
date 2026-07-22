import WaylandClient
import WaylandExampleSupport

@main
enum TabletInputSmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.TabletInputSmoke",
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
        log("feature: tablet-input")
        log("capability: zwp_tablet_manager_v2 \(availabilityDescription(capabilities.tablet))")

        guard capabilities.tablet.isAvailable else {
            log("operation: bind-seat skip(protocol-unavailable)")
            log("events: toolMotion=0 pressure=0 tilt=0 buttons=0")
            log("cleanup: pass")
            return
        }

        log("operation: bind-seat pass")

        let state = TabletInputSmokeState()
        let window = try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: "WaylandClientKit Tablet Input Smoke",
                appID: "wayland-client-kit-tablet-input-smoke",
                initialWidth: 420,
                initialHeight: 260,
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

        log(await state.summary())
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
        state: TabletInputSmokeState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event.kind {
            case .tablet(let tabletEvent):
                await state.record(tabletEvent)
                log("tablet event target=\(event.target) \(tabletDescription(tabletEvent))")
            case .seat(.removed):
                await state.recordSeatRemoval()
            default:
                break
            }

            if event.windowID == window.id {
                try await window.requestRedraw()
            }
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
                let blue = UInt32((row * 255) / max(Int(frame.height), 1))
                unsafe pixels[unchecked: x] = (red << 16) | 0x6600 | blue
            }
        }
    }

    nonisolated private static func availabilityDescription(
        _ availability: ProtocolAvailability
    ) -> String {
        switch availability {
        case .available(let version):
            "available version=\(version)"
        case .unavailable:
            "unavailable"
        }
    }

    nonisolated private static func tabletDescription(_ event: TabletEvent) -> String {
        switch event {
        case .tabletAdded(let tablet):
            "tabletAdded id=\(tablet)"
        case .toolAdded(let tool):
            "toolAdded id=\(tool)"
        case .padAdded(let pad):
            "padAdded id=\(pad)"
        case .tablet(let tabletEvent):
            "tablet \(tabletEvent)"
        case .tool(let toolEvent):
            "tool \(toolEvent)"
        case .pad(let padEvent):
            "pad \(padEvent)"
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[TabletInputSmoke] \(message)")
    }
}

private actor TabletInputSmokeState {
    private var tabletEvents = 0
    private var toolMotionEvents = 0
    private var pressureEvents = 0
    private var tiltEvents = 0
    private var buttonEvents = 0
    private var seatRemovals = 0

    func record(_ event: TabletEvent) {
        tabletEvents += 1
        switch event {
        case .tool(.motion):
            toolMotionEvents += 1
        case .tool(.pressure):
            pressureEvents += 1
        case .tool(.tilt):
            tiltEvents += 1
        case .tool(.button),
            .pad(.button):
            buttonEvents += 1
        default:
            break
        }
    }

    func recordSeatRemoval() {
        seatRemovals += 1
    }

    func summary() -> String {
        "events: total=\(tabletEvents) toolMotion=\(toolMotionEvents) "
            + "pressure=\(pressureEvents) tilt=\(tiltEvents) buttons=\(buttonEvents) "
            + "seatRemoved=\(seatRemovals)"
    }
}
