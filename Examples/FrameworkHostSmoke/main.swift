import Foundation
import WaylandClient

@main
enum FrameworkHostSmoke {
    static func main() async throws {
        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.FrameworkHostSmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                eventCapacity: 64,
                inputEventCapacity: 64,
                textInputEventCapacity: 32,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Framework Host Smoke",
                    appID: "wayland-client-kit-framework-host-smoke",
                    initialWidth: 240,
                    initialHeight: 160,
                    closeRequestPolicy: .requestOnly
                )
            )
            let state = FrameworkHostState()
            let loop = FrameworkWindowLoop(window: window, state: state)
            try await loop.showInitialFrame()

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await consumeDisplayEvents(
                        display.events,
                        window: window,
                        loop: loop,
                        state: state
                    )
                }
                group.addTask {
                    try await consumeInputEvents(display.inputEvents, window: window, state: state)
                }
                group.addTask {
                    try await consumeTextInputEvents(
                        display.textInputEvents,
                        window: window,
                        state: state
                    )
                }
                group.addTask {
                    try await consumeDiagnostics(display.diagnostics)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    await window.close()
                }

                _ = try await group.next()
                group.cancelAll()
            }
        }
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        window: Window,
        loop: FrameworkWindowLoop,
        state: FrameworkHostState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == window.id:
                try await loop.redrawIfNeeded()
            case .windowCloseRequested(let windowID) where windowID == window.id:
                await window.close()
            case .windowClosed(let windowID) where windowID == window.id:
                return
            case .windowOutputsChanged(let event) where event.windowID == window.id:
                await state.recordOutputs()
                if await state.consumeNeedsRedraw() {
                    try await window.requestRedraw()
                }
            case .input, .textInput, .dataTransfer, .presentation:
                break
            case .diagnostic(let diagnostic):
                log("display diagnostic \(diagnostic)")
            case .popupDismissed, .popupClosed, .popupRedrawRequested, .outputChanged,
                .outputRemoved, .windowCloseRequested, .windowClosed, .redrawRequested,
                .windowOutputsChanged, .keyboardShortcutsInhibitorChanged:
                break
            }
        }
    }

    nonisolated private static func consumeInputEvents(
        _ events: InputEvents,
        window: Window,
        state: FrameworkHostState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            await state.recordInput(event, windowID: window.id)
            if await state.consumeNeedsRedraw() {
                try await window.requestRedraw()
            }
        }
    }

    nonisolated private static func consumeTextInputEvents(
        _ events: TextInputEvents,
        window: Window,
        state: FrameworkHostState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            await state.recordTextInput(event)
            if await state.consumeNeedsRedraw() {
                try await window.requestRedraw()
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

    nonisolated private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

struct FrameworkWindowLoop: Sendable {
    let window: Window
    let state: FrameworkHostState

    nonisolated func showInitialFrame() async throws {
        let snapshot = await state.snapshot()
        try await window.show { frame in
            draw(frame, snapshot: snapshot)
        }
    }

    nonisolated func redrawIfNeeded() async throws {
        guard try await !window.isClosed else { return }
        guard try await window.needsRedraw else { return }
        let snapshot = await state.snapshot()
        try await window.redraw { frame in
            draw(frame, snapshot: snapshot)
        }
    }

    nonisolated private func draw(
        _ frame: borrowing SoftwareFrame,
        snapshot: FrameworkHostSnapshot
    ) {
        frame.withXRGB8888Rows { row, pixels in
            for index in 0..<pixels.count {
                let red = UInt32((index * 255) / max(pixels.count, 1))
                let green = UInt32((row * 255) / max(Int(frame.height), 1))
                let blue = UInt32((snapshot.counter * 17) & 0xFF)
                unsafe pixels[unchecked: index] = (red << 16) | (green << 8) | blue
            }
            if let pointer = snapshot.pointer {
                drawPointer(pointer, row: row, pixels: &pixels, geometry: frame.geometry)
            }
        }
    }

    nonisolated private func drawPointer(
        _ pointer: PointerLocation,
        row: Int,
        pixels: inout MutableSpan<UInt32>,
        geometry: SoftwareFrameGeometry
    ) {
        let point = geometry.bufferPixelPoint(logicalX: pointer.x, logicalY: pointer.y)
        let radius = 4
        guard abs(row - point.y) <= radius else { return }
        let start = max(point.x - radius, 0)
        let end = min(point.x + radius, pixels.count - 1)
        guard start <= end else { return }
        for index in start...end {
            unsafe pixels[unchecked: index] = 0x00FF_FFFF
        }
    }
}

actor FrameworkHostState {
    private var current = FrameworkHostSnapshot()
    private var redrawNeeded = false

    func recordInput(_ event: InputEvent, windowID: WindowID) {
        guard event.windowID == windowID || acceptsDisplayTarget(event.target) else {
            return
        }

        switch event.kind {
        case .pointer(.entered(let location, _)), .pointer(.moved(let location, _)):
            current.pointer = location
            current.counter += 1
            redrawNeeded = true
        case .pointer(.left):
            current.pointer = nil
            redrawNeeded = true
        case .keyboard(.interpreted(.key)):
            current.counter += 1
            redrawNeeded = true
        case .seat, .diagnostic, .pointer, .keyboard, .touch, .tablet:
            break
        }
    }

    func recordTextInput(_ event: TextInputEvent) {
        switch event {
        case .entered, .left:
            break
        case .transaction(let transaction):
            if transaction.committedText != nil {
                current.counter += 1
            }
            redrawNeeded =
                transaction.preedit != nil
                || transaction.deletion != nil
                || transaction.committedText != nil
        case .language, .diagnostic:
            break
        }
    }

    func recordOutputs() {
        redrawNeeded = true
    }

    func consumeNeedsRedraw() -> Bool {
        defer { redrawNeeded = false }
        return redrawNeeded
    }

    func snapshot() -> FrameworkHostSnapshot {
        return current
    }

    private func acceptsDisplayTarget(_ target: InputEventTarget) -> Bool {
        switch target {
        case .display, .focusless:
            true
        case .surface, .unmanagedSurface:
            false
        }
    }
}

struct FrameworkHostSnapshot: Sendable {
    var counter = 0
    var pointer: PointerLocation?
}
