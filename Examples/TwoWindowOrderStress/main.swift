import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum TwoWindowOrderStress {
    static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let options = try ExampleRunOptions.parse(arguments.filter { $0 != "--reversed" }[...])
        let reversed = arguments.contains("--reversed")

        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 128,
                inputEventCapacity: 4_096,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let descriptors = reversed ? Array(windowDescriptors.reversed()) : windowDescriptors
            var controllers: [OrderStressController] = []
            for descriptor in descriptors {
                let controller = try await makeController(display: display, descriptor: descriptor)
                controllers.append(controller)
            }
            let registry = OrderStressRegistry(controllers)

            log("purpose two-window input routing stress; resize traffic is expected")
            log("creation order \(controllers.map { $0.name }.joined(separator: ","))")
            for controller in controllers {
                log("window \(controller.name) id=\(controller.window.id)")
                try await controller.showInitialFrame()
            }
            let autoCloseControllers = controllers

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await consumeDisplayEvents(display.events, registry: registry)
                }
                group.addTask {
                    try await consumeInputEvents(display.inputEvents, registry: registry)
                }
                if let seconds = options.autoCloseSeconds {
                    group.addTask {
                        try await Task.sleep(for: .seconds(seconds))
                        for controller in autoCloseControllers {
                            await controller.window.close()
                        }
                    }
                }

                _ = try await group.next()
                group.cancelAll()
            }

            if options.printSummary {
                log(await registry.summary())
            }
        }
    }

    nonisolated private static let windowDescriptors: [OrderStressWindowDescriptor] = [
        OrderStressWindowDescriptor(name: "A", colorSeed: 0x28),
        OrderStressWindowDescriptor(name: "B", colorSeed: 0xA0),
    ]

    nonisolated private static func makeController(
        display: WaylandDisplay,
        descriptor: OrderStressWindowDescriptor
    ) async throws -> OrderStressController {
        let window = try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: "Order Stress \(descriptor.name)",
                appID: "swift-wayland-order-stress-\(descriptor.name.lowercased())",
                initialWidth: 320,
                initialHeight: 220,
                closeRequestPolicy: .requestOnly,
                decorationPreference: .preferClientSide
            )
        )
        return OrderStressController(
            name: descriptor.name,
            window: window,
            state: OrderStressState(colorSeed: descriptor.colorSeed)
        )
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        registry: OrderStressRegistry
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID):
                if let controller = await registry.controller(for: windowID) {
                    log("redraw requested window=\(controller.name) id=\(windowID)")
                    try await controller.redrawIfNeeded()
                }
            case .windowCloseRequested(let windowID):
                if let controller = await registry.controller(for: windowID) {
                    log("close requested window=\(controller.name) id=\(windowID)")
                    await controller.window.close()
                }
            case .windowClosed(let windowID):
                let remaining = await registry.remove(windowID)
                log("closed id=\(windowID) remaining=\(remaining)")
                if remaining == 0 { return }
            case .diagnostic(let diagnostic):
                log("display diagnostic \(diagnostic)")
            default:
                break
            }
        }
    }

    nonisolated private static func consumeInputEvents(
        _ events: InputEvents,
        registry: OrderStressRegistry
    ) async throws {
        var iterator = events.makeAsyncIterator()
        do {
            while !Task.isCancelled, let event = try await iterator.next() {
                guard let windowID = event.windowID,
                    let controller = await registry.controller(for: windowID)
                else {
                    continue
                }

                switch event.kind {
                case .pointer(.entered(let location, let serial)):
                    _ = await controller.state.recordPointer(location)
                    log("pointer entered window=\(controller.name) id=\(windowID) serial=\(serial)")
                    try await controller.window.requestRedraw()
                case .pointer(.moved(let location, _)):
                    let eventCount = await controller.state.recordPointer(location)
                    if eventCount.isMultiple(of: 8) {
                        try await controller.window.requestRedraw()
                    }
                case .pointer(.left(let serial)):
                    _ = await controller.state.recordPointer(nil)
                    log("pointer left window=\(controller.name) id=\(windowID) serial=\(serial)")
                    try await controller.window.requestRedraw()
                case .pointer(.button(let button)) where button.state == .pressed:
                    await controller.state.recordButtonPress()
                    let geometry = try await controller.window.geometry
                    let location = await controller.state.pointerLocation
                    let edge = location.flatMap { resizeEdge(at: $0, in: geometry) }
                    log(
                        "button press window=\(controller.name) id=\(windowID) "
                            + "button=\(button.button) serial=\(button.serial) edge=\(edgeDescription(edge))"
                    )
                    if let edge {
                        try await controller.window.requestInteractiveResize(
                            seatID: event.seatID,
                            serial: button.serial,
                            edge: edge
                        )
                        log(
                            "interactive resize requested window=\(controller.name) "
                                + "id=\(windowID) serial=\(button.serial) edge=\(edge)"
                        )
                    } else {
                        try await controller.window.requestRedraw()
                    }
                case .keyboard(.raw(.entered(let serial, _))):
                    log(
                        "keyboard entered window=\(controller.name) "
                            + "id=\(windowID) serial=\(serial)"
                    )
                case .keyboard(.raw(.left(let serial))):
                    log("keyboard left window=\(controller.name) id=\(windowID) serial=\(serial)")
                default:
                    break
                }
            }
        } catch {
            log("input stream stopped: \(overflowDescription(error))")
        }
    }

    nonisolated private static func resizeEdge(
        at location: PointerLocation,
        in geometry: SurfaceGeometry
    ) -> WindowResizeEdge? {
        let width = Double(geometry.logicalSize.width.rawValue)
        let height = Double(geometry.logicalSize.height.rawValue)
        let band = 14.0
        let top = location.y <= band
        let bottom = location.y >= height - band
        let left = location.x <= band
        let right = location.x >= width - band

        switch (top, bottom, left, right) {
        case (true, _, true, _):
            return .topLeft
        case (true, _, _, true):
            return .topRight
        case (_, true, true, _):
            return .bottomLeft
        case (_, true, _, true):
            return .bottomRight
        case (true, _, _, _):
            return .top
        case (_, true, _, _):
            return .bottom
        case (_, _, true, _):
            return .left
        case (_, _, _, true):
            return .right
        default:
            return nil
        }
    }

    nonisolated private static func edgeDescription(_ edge: WindowResizeEdge?) -> String {
        edge.map(String.init(describing:)) ?? "none"
    }

    nonisolated private static func overflowDescription(_ error: any Error) -> String {
        guard let displayError = error as? WaylandDisplayError else {
            return "\(error)"
        }

        return switch displayError {
        case .eventSubscriberOverflow(let stream, let capacity):
            "subscriber overflow stream=\(stream) capacity=\(capacity)"
        case .inputPipelineOverflow(let overflow):
            "input pipeline overflow stage=\(overflow.stage) capacity=\(overflow.capacity)"
        default:
            "\(error)"
        }
    }

    nonisolated private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

private struct OrderStressWindowDescriptor: Sendable {
    let name: String
    let colorSeed: UInt32
}

private struct OrderStressController: Sendable {
    let name: String
    let window: Window
    let state: OrderStressState

    func showInitialFrame() async throws {
        let snapshot = await state.snapshot()
        try await window.show { frame in
            draw(frame, snapshot: snapshot)
        }
    }

    func redrawIfNeeded() async throws {
        guard try await !window.isClosed else { return }
        guard try await window.needsRedraw else { return }
        let snapshot = await state.snapshot()
        try await window.redraw { frame in
            draw(frame, snapshot: snapshot)
        }
    }

    nonisolated private func draw(_ frame: borrowing SoftwareFrame, snapshot: OrderStressSnapshot) {
        frame.withXRGB8888Rows { row, pixels in
            for index in 0..<pixels.count {
                let pointerBias = snapshot.pointer == nil ? 0 : 64
                let red = UInt32((index + Int(snapshot.colorSeed) + pointerBias) & 0xFF)
                let green = UInt32((row * 2 + snapshot.eventCount * 11) & 0xFF)
                let blue = UInt32((snapshot.pressCount * 31 + Int(snapshot.colorSeed)) & 0xFF)
                unsafe pixels[unchecked: index] = (red << 16) | (green << 8) | blue
            }
        }
    }
}

private actor OrderStressRegistry {
    private var controllersByWindowID: [WindowID: OrderStressController]
    private let createdCount: Int
    private var closedCount = 0

    init(_ controllers: [OrderStressController]) {
        controllersByWindowID = Dictionary(
            uniqueKeysWithValues: controllers.map { ($0.window.id, $0) }
        )
        createdCount = controllers.count
    }

    func controller(for windowID: WindowID) -> OrderStressController? {
        controllersByWindowID[windowID]
    }

    func remove(_ windowID: WindowID) -> Int {
        if controllersByWindowID.removeValue(forKey: windowID) != nil {
            closedCount += 1
        }
        return controllersByWindowID.count
    }

    func summary() -> String {
        "two-window order stress summary created=\(createdCount) closed=\(closedCount) "
            + "remaining=\(controllersByWindowID.count)"
    }
}

private actor OrderStressState {
    private var current: OrderStressSnapshot

    init(colorSeed: UInt32) {
        current = OrderStressSnapshot(colorSeed: colorSeed)
    }

    var pointerLocation: PointerLocation? {
        current.pointer
    }

    func recordPointer(_ location: PointerLocation?) -> Int {
        current.pointer = location
        current.eventCount += 1
        return current.eventCount
    }

    func recordButtonPress() {
        current.pressCount += 1
        current.eventCount += 1
    }

    func snapshot() -> OrderStressSnapshot {
        current
    }
}

private struct OrderStressSnapshot: Sendable {
    var colorSeed: UInt32
    var pointer: PointerLocation?
    var eventCount = 0
    var pressCount = 0
}
