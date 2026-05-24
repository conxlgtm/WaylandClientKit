import Foundation
import WaylandClient

@main
enum PresentationFeedbackAnimation {
    static func main() async throws {
        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 64
            )
        ) { display in
            let capabilities = try await display.capabilities()
            let usePresentationFeedback = capabilities.presentationTime.isAvailable
            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "SwiftWayland Presentation Animation",
                    appID: "swift-wayland-presentation-animation",
                    initialWidth: 360,
                    initialHeight: 240,
                    closeRequestPolicy: .requestOnly
                )
            )
            let animation = AnimationState()

            try await window.show { frame in
                draw(frame, phase: 0)
            }
            try await window.requestRedraw()

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await consumeDisplayEvents(
                        display.events,
                        window: window,
                        animation: animation,
                        usePresentationFeedback: usePresentationFeedback
                    )
                }
                group.addTask {
                    try await consumePresentationEvents(window.presentationEvents)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(10))
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
        animation: AnimationState,
        usePresentationFeedback: Bool
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == window.id:
                let phase = await animation.nextPhase()
                if usePresentationFeedback {
                    try? await window.requestPresentationFeedback()
                }
                try await window.redraw { frame in
                    draw(frame, phase: phase)
                }
                if try await !window.isClosed {
                    try await window.requestRedraw()
                }
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

    nonisolated private static func consumePresentationEvents(
        _ events: WindowPresentationEvents
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .presented(let feedback):
                log("presented \(feedback.surface) sequence=\(feedback.sequence.value)")
            case .discarded(let identity):
                log("discarded \(identity)")
            }
        }
    }

    nonisolated private static func draw(_ frame: borrowing SoftwareFrame, phase: Int) {
        frame.withXRGB8888Rows { row, pixels in
            for index in 0..<pixels.count {
                let red = UInt32((index + phase * 3) & 0xFF)
                let green = UInt32((row * 2 + phase * 5) & 0xFF)
                let blue = UInt32((index + row + phase * 7) & 0xFF)
                unsafe pixels[unchecked: index] = (red << 16) | (green << 8) | blue
            }
        }
    }

    nonisolated private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

actor AnimationState {
    private var phase = 0

    func nextPhase() -> Int {
        defer { phase += 1 }
        return phase
    }
}
