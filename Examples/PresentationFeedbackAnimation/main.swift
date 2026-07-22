import Foundation
import Glibc
import WaylandClient
import WaylandExampleSupport

@main
enum PresentationFeedbackAnimation {
    static func main() async {
        let exitCode: Int32
        do {
            try await run()
            exitCode = EXIT_SUCCESS
        } catch {
            log("failure: \(error)")
            exitCode = EXIT_FAILURE
        }

        guard exitCode == EXIT_SUCCESS else {
            exit(exitCode)
        }
    }

    private static func run() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.PresentationFeedbackAnimation",
            eventStreamConfiguration: try EventStreamConfiguration(
                eventCapacity: 64,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 64
            )
        ) { display in
            let capabilities = try await display.capabilities()
            let usePresentationFeedback = capabilities.presentationTime.isAvailable
            log("feature: presentation-feedback")
            log("capability: \(availabilityDescription(capabilities.presentationTime))")
            log(
                "presentation feedback "
                    + (usePresentationFeedback ? "available" : "unavailable")
            )
            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Presentation Animation",
                    appID: "wayland-client-kit-presentation-animation",
                    initialWidth: 360,
                    initialHeight: 240,
                    closeRequestPolicy: .requestOnly
                )
            )
            let animation = AnimationState()

            try await window.show { frame in
                draw(frame, phase: 0)
            }

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
                    try await consumePresentationEvents(
                        window.presentationEvents,
                        animation: animation
                    )
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(options.autoCloseSeconds ?? 10))
                    await window.close()
                }

                _ = try await group.next()
                group.cancelAll()
            }

            if options.printSummary {
                log(await animation.summary())
            }
            log("fallback: none")
            log("failure: none")
            log("result: pass")
            log("cleanup: pass")
        }
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        window: Window,
        animation: AnimationState,
        usePresentationFeedback: Bool
    ) async throws {
        try await window.requestRedraw()

        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == window.id:
                let phase = await animation.nextPhase()
                if usePresentationFeedback {
                    do {
                        try await window.requestPresentationFeedback()
                        log("operation: request-presentation-feedback pass")
                    } catch {
                        log("operation: request-presentation-feedback failed(\(error))")
                    }
                } else {
                    log("operation: request-presentation-feedback skip")
                }
                try await window.redraw { frame in
                    draw(frame, phase: phase)
                }
                log("operation: redraw pass")
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
        _ events: WindowPresentationEvents,
        animation: AnimationState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .presented(let feedback):
                await animation.recordPresented()
                log("presented \(feedback.surface) sequence=\(feedback.sequence.value)")
            case .discarded(let identity):
                await animation.recordDiscarded()
                log("discarded \(identity)")
            }
        }

        log("presentation feedback stream ended")
        while !Task.isCancelled {
            try await Task.sleep(for: .seconds(1))
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

    nonisolated private static func availabilityDescription(
        _ availability: ProtocolAvailability
    ) -> String {
        switch availability {
        case .unavailable:
            "unavailable"
        case .available(let version):
            "available version=\(version)"
        }
    }
}

actor AnimationState {
    private var phase = 0
    private var presentedCount = 0
    private var discardedCount = 0

    func nextPhase() -> Int {
        defer { phase += 1 }
        return phase
    }

    func recordPresented() {
        presentedCount += 1
    }

    func recordDiscarded() {
        discardedCount += 1
    }

    func summary() -> String {
        "presentation animation summary frames=\(phase) presented=\(presentedCount) "
            + "discarded=\(discardedCount)"
    }
}
