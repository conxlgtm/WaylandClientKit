import Foundation
import WaylandClient

@main
enum ClientSideResizeChrome {
    static func main() async throws {
        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 128,
                inputEventCapacity: 128,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let controllers = [
                try await makeController(
                    display: display,
                    title: "Resize Chrome A",
                    appID: "swift-wayland-resize-chrome-a",
                    colorSeed: 0x20
                ),
                try await makeController(
                    display: display,
                    title: "Resize Chrome B",
                    appID: "swift-wayland-resize-chrome-b",
                    colorSeed: 0x80
                ),
            ]
            let registry = ResizeWindowRegistry(controllers)

            for controller in controllers {
                try await controller.showInitialFrame()
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await consumeDisplayEvents(display.events, registry: registry)
                }
                group.addTask {
                    try await consumeInputEvents(
                        display.inputEvents,
                        display: display,
                        registry: registry
                    )
                }

                _ = try await group.next()
                group.cancelAll()
            }
        }
    }

    nonisolated private static func makeController(
        display: WaylandDisplay,
        title: String,
        appID: String,
        colorSeed: UInt32
    ) async throws -> ResizeWindowController {
        let window = try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: title,
                appID: appID,
                initialWidth: 320,
                initialHeight: 220,
                closeRequestPolicy: .requestOnly,
                decorationPreference: .preferClientSide
            )
        )
        return ResizeWindowController(
            window: window,
            state: ResizeWindowState(colorSeed: colorSeed)
        )
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        registry: ResizeWindowRegistry
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID):
                if let controller = await registry.controller(for: windowID) {
                    try await controller.redrawIfNeeded()
                }
            case .windowCloseRequested(let windowID):
                if let controller = await registry.controller(for: windowID) {
                    await controller.window.close()
                }
            case .windowClosed(let windowID):
                if await registry.remove(windowID) {
                    return
                }
            case .diagnostic(let diagnostic):
                log("display diagnostic \(diagnostic)")
            default:
                break
            }
        }
    }

    nonisolated private static func consumeInputEvents(
        _ events: InputEvents,
        display: WaylandDisplay,
        registry: ResizeWindowRegistry
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard let windowID = event.windowID,
                let controller = await registry.controller(for: windowID)
            else {
                continue
            }

            switch event.kind {
            case .pointer(.entered(let location, _)), .pointer(.moved(let location, _)):
                await controller.state.recordPointer(location)
                let edge = try await resizeEdge(at: location, in: controller.window.geometry)
                _ = try? await display.setPointerCursor(cursor(for: edge))
                try await controller.window.requestRedraw()
            case .pointer(.left):
                await controller.state.recordPointer(nil)
                _ = try? await display.setPointerCursor(.defaultArrow)
                try await controller.window.requestRedraw()
            case .pointer(.button(let button)) where button.state == .pressed:
                guard let location = await controller.state.pointerLocation else { continue }
                let geometry = try await controller.window.geometry
                guard let edge = resizeEdge(at: location, in: geometry) else { continue }
                try await controller.window.requestInteractiveResize(
                    seatID: event.seatID,
                    serial: button.serial,
                    edge: edge
                )
            default:
                break
            }
        }
    }

    nonisolated private static func resizeEdge(
        at location: PointerLocation,
        in geometry: SurfaceGeometry
    ) -> WindowResizeEdge? {
        let width = Double(geometry.logicalSize.width.rawValue)
        let height = Double(geometry.logicalSize.height.rawValue)
        let band = 12.0
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

    nonisolated private static func cursor(for edge: WindowResizeEdge?) -> PointerCursor {
        guard let edge else { return .defaultArrow }
        switch edge {
        case .left, .right:
            return .resizeLeftRight
        case .top, .bottom:
            return .resizeUpDown
        case .topLeft:
            return (try? PointerCursor(name: "nw-resize")) ?? .crosshair
        case .topRight:
            return (try? PointerCursor(name: "ne-resize")) ?? .crosshair
        case .bottomLeft:
            return (try? PointerCursor(name: "sw-resize")) ?? .crosshair
        case .bottomRight:
            return (try? PointerCursor(name: "se-resize")) ?? .crosshair
        }
    }

    nonisolated private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

private struct ResizeWindowController: Sendable {
    let window: Window
    let state: ResizeWindowState

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

    nonisolated private func draw(_ frame: borrowing SoftwareFrame, snapshot: ResizeSnapshot) {
        frame.withXRGB8888Rows { row, pixels in
            for index in 0..<pixels.count {
                let red = UInt32((index + Int(snapshot.colorSeed)) & 0xFF)
                let green = UInt32((row * 2 + snapshot.counter * 9) & 0xFF)
                let blue = UInt32((snapshot.counter * 13 + Int(snapshot.colorSeed)) & 0xFF)
                unsafe pixels[unchecked: index] = (red << 16) | (green << 8) | blue
            }
        }
    }
}

private actor ResizeWindowRegistry {
    private var controllersByWindowID: [WindowID: ResizeWindowController]

    init(_ controllers: [ResizeWindowController]) {
        controllersByWindowID = Dictionary(
            uniqueKeysWithValues: controllers.map { ($0.window.id, $0) }
        )
    }

    func controller(for windowID: WindowID) -> ResizeWindowController? {
        controllersByWindowID[windowID]
    }

    func remove(_ windowID: WindowID) -> Bool {
        controllersByWindowID.removeValue(forKey: windowID)
        return controllersByWindowID.isEmpty
    }
}

private actor ResizeWindowState {
    private var current: ResizeSnapshot

    init(colorSeed: UInt32) {
        current = ResizeSnapshot(colorSeed: colorSeed)
    }

    var pointerLocation: PointerLocation? {
        current.pointer
    }

    func recordPointer(_ location: PointerLocation?) {
        current.pointer = location
        current.counter += 1
    }

    func snapshot() -> ResizeSnapshot {
        current
    }
}

private struct ResizeSnapshot: Sendable {
    var colorSeed: UInt32
    var counter = 0
    var pointer: PointerLocation?
}
