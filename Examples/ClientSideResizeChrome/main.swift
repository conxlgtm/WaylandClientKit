import Foundation
import WaylandClient
import WaylandExampleSupport

// swiftlint:disable cyclomatic_complexity function_body_length type_body_length
@main
enum ClientSideResizeChrome {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())
        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 128,
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

        log("client-side chrome policy lives above SwiftWayland")
        for controller in controllers {
            log("registered resize window=\(controller.window.id)")
        }
        for controller in controllers {
            try await controller.showInitialFrame()
            log("first show resize window=\(controller.window.id)")
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
            if let seconds = options.autoCloseSeconds {
                group.addTask {
                    try await Task.sleep(for: .seconds(seconds))
                    await registry.closeAll()
                    try await waitForCancellation()
                }
            }

            _ = try await group.next()
            group.cancelAll()
        }
        if options.printSummary {
            log(await registry.summary())
        }
    }

    nonisolated private static func waitForCancellation() async throws {
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(60))
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
                let edge = try await resizeEdge(at: location, in: controller.window.geometry)
                let cursor = cursor(for: edge)
                let changed = await controller.state.recordPointer(
                    location,
                    edge: edge,
                    cursor: cursor
                )
                do {
                    let results = try await display.setPointerCursor(cursor)
                    if changed {
                        logCursorChange(
                            windowID: windowID, edge: edge, cursor: cursor, results: results)
                    }
                } catch {
                    log(
                        "cursor failed window=\(windowID) edge=\(edgeDescription(edge)) "
                            + "cursor=\(cursorDescription(cursor)) error=\(error)"
                    )
                }
                try await controller.window.requestRedraw()
            case .pointer(.left):
                _ = await controller.state.recordPointer(
                    nil,
                    edge: nil,
                    cursor: .defaultArrow
                )
                do {
                    let results = try await display.setPointerCursor(.defaultArrow)
                    log(
                        "cursor window=\(windowID) edge=none cursor=left_ptr "
                            + "results=\(cursorResultsDescription(results))"
                    )
                } catch {
                    log(
                        "cursor failed window=\(windowID) edge=none "
                            + "cursor=left_ptr error=\(error)"
                    )
                }
                try await controller.window.requestRedraw()
            case .pointer(.button(let button)) where button.state == .pressed:
                guard let location = await controller.state.pointerLocation else { continue }
                let geometry = try await controller.window.geometry
                guard let edge = resizeEdge(at: location, in: geometry) else { continue }
                log(
                    "resize request window=\(windowID) seat=\(event.seatID) "
                        + "serial=\(button.serial) edge=\(edgeDescription(edge)) "
                        + "geometry=\(geometryDescription(geometry)) "
                        + "location=\(location.x),\(location.y)"
                )
                do {
                    try await controller.window.requestInteractiveResize(
                        seatID: event.seatID,
                        serial: button.serial,
                        edge: edge
                    )
                    log("resize request result window=\(windowID) threw=false")
                } catch {
                    log("resize request result window=\(windowID) threw=true error=\(error)")
                }
            default:
                break
            }
        }
    }

    nonisolated private static func logCursorChange(
        windowID: WindowID,
        edge: WindowResizeEdge?,
        cursor: PointerCursor,
        results: [CursorRequestResult]
    ) {
        log(
            "cursor window=\(windowID) edge=\(edgeDescription(edge)) "
                + "cursor=\(cursorDescription(cursor)) "
                + "results=\(cursorResultsDescription(results))"
        )
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

    nonisolated private static func edgeDescription(_ edge: WindowResizeEdge?) -> String {
        guard let edge else { return "none" }
        switch edge {
        case .top:
            return "top"
        case .bottom:
            return "bottom"
        case .left:
            return "left"
        case .right:
            return "right"
        case .topLeft:
            return "topLeft"
        case .topRight:
            return "topRight"
        case .bottomLeft:
            return "bottomLeft"
        case .bottomRight:
            return "bottomRight"
        }
    }

    nonisolated private static func cursorDescription(_ cursor: PointerCursor) -> String {
        cursor.name ?? "hidden"
    }

    nonisolated private static func cursorResultsDescription(
        _ results: [CursorRequestResult]
    ) -> String {
        if results.isEmpty { return "none" }
        return results.map(cursorResultDescription).joined(separator: ",")
    }

    nonisolated private static func cursorResultDescription(
        _ result: CursorRequestResult
    ) -> String {
        switch result {
        case .set(let seatID, let serial, let cursor):
            return "set(seat=\(seatID),serial=\(serial),cursor=\(cursorDescription(cursor)))"
        case .hidden(let seatID, let serial):
            return "hidden(seat=\(seatID),serial=\(serial))"
        case .skippedNoPointerFocus(let seatID):
            return "skippedNoPointerFocus(seat=\(seatID))"
        }
    }

    nonisolated private static func geometryDescription(_ geometry: SurfaceGeometry) -> String {
        let size = geometry.logicalSize
        return "\(size.width.rawValue)x\(size.height.rawValue)"
    }

    nonisolated private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
// swiftlint:enable cyclomatic_complexity function_body_length type_body_length

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

    func closeAll() async {
        for controller in controllersByWindowID.values {
            await controller.window.close()
        }
    }

    func summary() -> String {
        "client-side resize summary remainingWindows=\(controllersByWindowID.count)"
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

    func recordPointer(
        _ location: PointerLocation?,
        edge: WindowResizeEdge?,
        cursor: PointerCursor
    ) -> Bool {
        let changed = current.edge != edge || current.cursor != cursor
        current.pointer = location
        current.edge = edge
        current.cursor = cursor
        current.counter += 1
        return changed
    }

    func snapshot() -> ResizeSnapshot {
        current
    }
}

private struct ResizeSnapshot: Sendable {
    var colorSeed: UInt32
    var counter = 0
    var pointer: PointerLocation?
    var edge: WindowResizeEdge?
    var cursor = PointerCursor.defaultArrow
}
