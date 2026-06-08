import Foundation
import WaylandClient
import WaylandExampleSupport

// swiftlint:disable type_body_length
@main
enum SerialActionsProbe {
    nonisolated private static let leftButton = PointerButtonCode(rawValue: 0x110)
    nonisolated private static let rightButton = PointerButtonCode(rawValue: 0x111)
    nonisolated private static let middleButton = PointerButtonCode(rawValue: 0x112)

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
        log("display capabilities \(capabilitiesDescription(capabilities))")

        let window = try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: "SwiftWayland Serial Actions Probe",
                appID: "swift-wayland-serial-actions-probe",
                initialWidth: 360,
                initialHeight: 220,
                closeRequestPolicy: .requestOnly,
                decorationPreference: .preferClientSide
            )
        )
        let state = SerialProbeState()
        try await showInitialFrame(window: window, state: state)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await consumeDisplayEvents(
                    display.events,
                    window: window,
                    state: state
                )
            }
            group.addTask {
                try await consumeInputEvents(
                    display.inputEvents,
                    window: window,
                    state: state
                )
            }
            group.addTask {
                try await consumeDiagnostics(display.diagnostics)
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
            log(await state.summary())
        }
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        window: Window,
        state: SerialProbeState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == window.id:
                try await redrawIfNeeded(window: window, state: state)
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
        state: SerialProbeState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard event.windowID == window.id else { continue }

            switch event.kind {
            case .pointer(.entered(let location, let serial)):
                await state.recordPointer(location)
                log(
                    "pointer entered seat=\(event.seatID) serial=\(serial) "
                        + "location=\(locationDescription(location))"
                )
                try await window.requestRedraw()
            case .pointer(.moved(let location, _)):
                await state.recordPointer(location)
                try await window.requestRedraw()
            case .pointer(.left(let serial)):
                await state.recordPointer(nil)
                log("pointer left seat=\(event.seatID) serial=\(serial)")
                try await window.requestRedraw()
            case .pointer(.button(let button)) where button.state == .pressed:
                let location = await state.pointerLocation
                try await performSerialAction(
                    button: button,
                    seatID: event.seatID,
                    location: location,
                    window: window,
                    state: state
                )
            default:
                break
            }
        }
    }

    nonisolated private static func consumeDiagnostics(
        _ diagnostics: DisplayDiagnostics
    ) async throws {
        var iterator = diagnostics.makeAsyncIterator()
        while !Task.isCancelled, let diagnostic = try await iterator.next() {
            log("diagnostic \(diagnostic)")
        }
    }

    nonisolated private static func performSerialAction(
        button: PointerButtonEvent,
        seatID: SeatID,
        location: PointerLocation?,
        window: Window,
        state: SerialProbeState
    ) async throws {
        await state.recordButtonPress()
        let action = actionName(for: button.button)
        let decorationMode = try await window.decorationMode
        let snapshot = try await window.stateSnapshot

        log(
            "serial action attempt action=\(action) window=\(window.id) seat=\(seatID) "
                + "serial=\(button.serial) button=\(button.button) "
                + "location=\(locationDescription(location)) decoration=\(decorationMode) "
                + "snapshot=\(snapshotDescription(snapshot)) "
                + "managerCapabilities=\(snapshot.managerCapabilities)"
        )

        do {
            switch button.button {
            case leftButton:
                try await window.requestInteractiveMove(
                    seatID: seatID,
                    serial: button.serial
                )
            case middleButton:
                try await window.requestInteractiveResize(
                    seatID: seatID,
                    serial: button.serial,
                    edge: .bottomRight
                )
            case rightButton:
                try await window.requestWindowMenu(
                    seatID: seatID,
                    serial: button.serial,
                    position: menuPosition(for: location)
                )
            default:
                break
            }
            log(
                "serial action result action=\(action) window=\(window.id) "
                    + "seat=\(seatID) serial=\(button.serial) threw=false"
            )
        } catch {
            log(
                "serial action result action=\(action) window=\(window.id) "
                    + "seat=\(seatID) serial=\(button.serial) threw=true error=\(error)"
            )
        }

        try await window.requestRedraw()
    }

    nonisolated private static func actionName(for button: PointerButtonCode) -> String {
        switch button {
        case leftButton:
            "move"
        case middleButton:
            "resize"
        case rightButton:
            "window-menu"
        default:
            "ignored"
        }
    }

    nonisolated private static func menuPosition(for location: PointerLocation?) -> LogicalOffset {
        guard let location else { return .zero }
        return LogicalOffset(
            x: Int32(location.x.rounded(.toNearestOrAwayFromZero)),
            y: Int32(location.y.rounded(.toNearestOrAwayFromZero))
        )
    }

    nonisolated private static func showInitialFrame(
        window: Window,
        state: SerialProbeState
    ) async throws {
        let snapshot = await state.snapshot()
        try await window.show { frame in
            draw(frame, snapshot: snapshot)
        }
    }

    nonisolated private static func redrawIfNeeded(
        window: Window,
        state: SerialProbeState
    ) async throws {
        guard try await !window.isClosed else { return }
        guard try await window.needsRedraw else { return }
        let snapshot = await state.snapshot()
        try await window.redraw { frame in
            draw(frame, snapshot: snapshot)
        }
    }

    nonisolated private static func draw(
        _ frame: borrowing SoftwareFrame,
        snapshot: SerialProbeSnapshot
    ) {
        frame.withXRGB8888Rows { row, pixels in
            for index in 0..<pixels.count {
                let pointerBias = snapshot.pointerLocation == nil ? 0 : 80
                let red = UInt32((row * 3 + snapshot.eventCount * 13) & 0xFF)
                let green = UInt32((index + snapshot.pressCount * 29) & 0xFF)
                let blue = UInt32((pointerBias + row + index) & 0xFF)
                unsafe pixels[unchecked: index] = (red << 16) | (green << 8) | blue
            }
        }
    }

    nonisolated private static func locationDescription(_ location: PointerLocation?) -> String {
        guard let location else { return "none" }
        return locationDescription(location)
    }

    nonisolated private static func locationDescription(_ location: PointerLocation) -> String {
        "x=\(location.x) y=\(location.y)"
    }

    nonisolated private static func snapshotDescription(_ snapshot: WindowStateSnapshot) -> String {
        "configureSerial=\(snapshot.configureSerial) size=\(snapshot.size) "
            + "states=\(snapshot.states) bounds=\(String(describing: snapshot.bounds)) "
            + "decoration=\(String(describing: snapshot.decorationMode)) "
            + "outputs=\(snapshot.outputs)"
    }

    nonisolated private static func capabilitiesDescription(
        _ capabilities: WaylandCapabilities
    ) -> String {
        "xdgDecoration=\(availabilityDescription(capabilities.xdgDecoration)) "
            + "dragAndDrop=\(availabilityDescription(capabilities.dragAndDrop)) "
            + "dragActions=\(availabilityDescription(capabilities.dragActionNegotiation)) "
            + "cursorShape=\(availabilityDescription(capabilities.cursorShape))"
    }

    nonisolated private static func availabilityDescription(
        _ availability: ProtocolAvailability
    ) -> String {
        switch availability {
        case .available(let version):
            "available(v\(version))"
        case .unavailable:
            "unavailable"
        }
    }

    nonisolated private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
// swiftlint:enable type_body_length

private actor SerialProbeState {
    private var current = SerialProbeSnapshot()

    var pointerLocation: PointerLocation? {
        current.pointerLocation
    }

    func recordPointer(_ location: PointerLocation?) {
        current.pointerLocation = location
        current.eventCount += 1
    }

    func recordButtonPress() {
        current.pressCount += 1
        current.eventCount += 1
    }

    func snapshot() -> SerialProbeSnapshot {
        current
    }

    func summary() -> String {
        "serial-actions summary events=\(current.eventCount) buttonPresses=\(current.pressCount)"
    }
}

private struct SerialProbeSnapshot: Sendable {
    var pointerLocation: PointerLocation?
    var eventCount = 0
    var pressCount = 0
}
