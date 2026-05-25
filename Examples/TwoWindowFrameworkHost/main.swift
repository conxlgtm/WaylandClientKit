import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum TwoWindowFrameworkHost {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 128,
                inputEventCapacity: 128,
                textInputEventCapacity: 64,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let first = try await makeController(
                display: display,
                title: "SwiftWayland Window A",
                appID: "swift-wayland-two-window-a",
                colorSeed: 0x30
            )
            let second = try await makeController(
                display: display,
                title: "SwiftWayland Window B",
                appID: "swift-wayland-two-window-b",
                colorSeed: 0x90
            )
            let registry = WindowControllerRegistry([first, second])

            log("registered window id=\(first.window.id) label=SwiftWayland Window A")
            log("registered window id=\(second.window.id) label=SwiftWayland Window B")
            try await first.showInitialFrame()
            log("first show window=\(first.window.id)")
            try await second.showInitialFrame()
            log("first show window=\(second.window.id)")

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await consumeDisplayEvents(display.events, registry: registry)
                }
                group.addTask {
                    try await consumeInputEvents(display.inputEvents, registry: registry)
                }
                group.addTask {
                    try await consumeTextInputEvents(display.textInputEvents, registry: registry)
                }
                if let seconds = options.autoCloseSeconds {
                    group.addTask {
                        try await Task.sleep(for: .seconds(seconds))
                        await first.window.close()
                        await second.window.close()
                    }
                } else {
                    group.addTask {
                        try await Task.sleep(for: .seconds(6))
                        await first.window.close()
                    }
                    group.addTask {
                        try await Task.sleep(for: .seconds(10))
                        await second.window.close()
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

    nonisolated private static func makeController(
        display: WaylandDisplay,
        title: String,
        appID: String,
        colorSeed: UInt32
    ) async throws -> WindowController {
        let window = try await display.createTopLevelWindow(
            configuration: try WindowConfiguration(
                title: title,
                appID: appID,
                initialWidth: 280,
                initialHeight: 180,
                closeRequestPolicy: .requestOnly
            )
        )
        return WindowController(
            window: window,
            state: WindowState(label: title, colorSeed: colorSeed)
        )
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        registry: WindowControllerRegistry
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID):
                if let controller = await registry.controller(for: windowID) {
                    log("redraw requested window=\(windowID)")
                    try await controller.redrawIfNeeded()
                }
            case .windowCloseRequested(let windowID):
                if let controller = await registry.controller(for: windowID) {
                    log("close requested window=\(windowID)")
                    await controller.window.close()
                }
            case .windowClosed(let windowID):
                log("closed window=\(windowID)")
                if await registry.remove(windowID) {
                    return
                }
            case .windowOutputsChanged(let event):
                if let controller = await registry.controller(for: event.windowID) {
                    await controller.state.recordOutputs(event.outputs.count)
                    try await controller.window.requestRedraw()
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
        registry: WindowControllerRegistry
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard let windowID = event.windowID,
                let controller = await registry.controller(for: windowID)
            else {
                continue
            }

            await controller.state.recordInput(event)
            try await controller.window.requestRedraw()
        }
    }

    nonisolated private static func consumeTextInputEvents(
        _ events: TextInputEvents,
        registry: WindowControllerRegistry
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard let windowID = event.windowID,
                let controller = await registry.controller(for: windowID)
            else {
                continue
            }

            await controller.state.recordTextInput(event)
            try await controller.window.requestRedraw()
        }
    }

    nonisolated private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

private struct WindowController: Sendable {
    let window: Window
    let state: WindowState

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

    nonisolated private func draw(_ frame: borrowing SoftwareFrame, snapshot: WindowSnapshot) {
        frame.withXRGB8888Rows { row, pixels in
            for index in 0..<pixels.count {
                let red = UInt32((index + snapshot.counter * 3) & 0xFF)
                let green = UInt32((row + Int(snapshot.colorSeed)) & 0xFF)
                let blue = UInt32((snapshot.counter * 11 + Int(snapshot.colorSeed)) & 0xFF)
                unsafe pixels[unchecked: index] = (red << 16) | (green << 8) | blue
            }
        }
    }
}

private actor WindowControllerRegistry {
    private var controllersByWindowID: [WindowID: WindowController]
    private let createdCount: Int
    private var closedCount = 0

    init(_ controllers: [WindowController]) {
        controllersByWindowID = Dictionary(
            uniqueKeysWithValues: controllers.map { ($0.window.id, $0) }
        )
        createdCount = controllers.count
    }

    func controller(for windowID: WindowID) -> WindowController? {
        controllersByWindowID[windowID]
    }

    func remove(_ windowID: WindowID) -> Bool {
        if controllersByWindowID.removeValue(forKey: windowID) != nil {
            closedCount += 1
        }
        return controllersByWindowID.isEmpty
    }

    func summary() -> String {
        "two-window host summary created=\(createdCount) closed=\(closedCount) "
            + "remaining=\(controllersByWindowID.count)"
    }
}

private actor WindowState {
    private var current: WindowSnapshot

    init(label: String, colorSeed: UInt32) {
        current = WindowSnapshot(label: label, colorSeed: colorSeed)
    }

    func recordInput(_ event: InputEvent) {
        switch event.kind {
        case .pointer(.entered(let location, _)), .pointer(.moved(let location, _)):
            current.pointerFocus = event.windowID
            current.pointer = location
            current.counter += 1
        case .pointer(.left):
            current.pointerFocus = nil
            current.pointer = nil
            current.counter += 1
        case .keyboard(.raw(.entered)):
            current.keyboardFocus = event.windowID
            current.counter += 1
        case .keyboard(.raw(.left)):
            current.keyboardFocus = nil
            current.counter += 1
        case .keyboard(.interpreted(.key(let key))):
            current.lastKey = key.keyText ?? key.keysymName
            current.counter += 1
        case .seat, .diagnostic, .pointer, .keyboard, .touch:
            break
        }
    }

    func recordTextInput(_ event: TextInputEvent) {
        current.textInputFocus = event.windowID
        current.counter += 1
    }

    func recordOutputs(_ count: Int) {
        current.outputCount = count
        current.counter += 1
    }

    func snapshot() -> WindowSnapshot {
        current
    }
}

private struct WindowSnapshot: Sendable {
    var label: String
    var colorSeed: UInt32
    var counter = 0
    var outputCount = 0
    var pointer: PointerLocation?
    var pointerFocus: WindowID?
    var keyboardFocus: WindowID?
    var textInputFocus: WindowID?
    var lastKey: String?
}

extension TextInputEvent {
    nonisolated fileprivate var windowID: WindowID? {
        switch self {
        case .entered(let focus), .left(let focus):
            focus.target.windowID
        case .preedit, .committed, .deleteSurroundingText, .action, .language, .done,
            .diagnostic:
            nil
        }
    }
}

extension InputEventTarget {
    nonisolated fileprivate var windowID: WindowID? {
        switch self {
        case .surface(let surfaceTarget):
            surfaceTarget.windowID
        case .display, .unmanagedSurface, .focusless:
            nil
        }
    }
}
