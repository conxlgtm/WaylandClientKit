import Foundation
import Testing
import WaylandClient

let publicIntegrationTimeoutMilliseconds: Int32 = 5_000
let publicIntegrationWaitTimeoutNanoseconds: UInt64 = 5_000_000_000

@Suite(
    "WaylandDisplay public integration",
    .enabled(
        if: PublicIntegrationEnvironment.isEnabled,
        "Set WAYLAND_DISPLAY and WAYLAND_CLIENT_KIT_ENABLE_PUBLIC_INTEGRATION_TESTS=1"
    ),
    .timeLimit(.minutes(1)),
    .serialized
)
struct WaylandDisplayPublicIntegrationTests {
    @Test
    func connectionCloseFinishesPublicStreams() async throws {
        try await withPublicConnection { display in
            let displayEvents = display.events
            let inputEvents = display.inputEvents
            let dataTransferEvents = display.dataTransferEvents
            let textInputEvents = display.textInputEvents
            let diagnostics = display.diagnostics

            let streamResults = try await streamCloseResults(
                sources: PublicStreamSources(
                    displayEvents: displayEvents,
                    inputEvents: inputEvents,
                    dataTransferEvents: dataTransferEvents,
                    textInputEvents: textInputEvents,
                    diagnostics: diagnostics
                )
            ) {
                await display.close()
            }

            #expect(streamResults.count == 5)
            #expect(!streamResults.contains(false))
            #expect(await display.isClosed)
        }
    }

    @Test
    func toplevelWindowShowsRedrawsAndClosesThroughPublicAPI() async throws {
        try await withPublicConnection { display in
            let displayEvents = display.events
            let window = try await display.createTopLevelWindow(
                configuration: testWindowConfiguration()
            )

            try await show(window, color: 0x0010_2030)

            let initialGeometry = try await window.geometry
            #expect(initialGeometry.logicalSize.width.rawValue > 0)
            #expect(initialGeometry.logicalSize.height.rawValue > 0)
            #expect(try await !window.isClosed)
            _ = try await window.decorationMode

            let redrawEvent = try await displayEvent(
                in: displayEvents,
                matching: { event in
                    event == .redrawRequested(window.id)
                },
                after: {
                    try await window.requestRedraw()
                }
            )
            #expect(redrawEvent == .redrawRequested(window.id))
            #expect(try await window.needsRedraw)

            try await window.redraw { frame in
                fill(frame, color: 0x0030_2010)
            }

            try await close(window, events: displayEvents)
        }
    }

    @Test
    func popupShowsRedrawsAndClosesThroughPublicAPI() async throws {
        try await withPublicConnection { display in
            let displayEvents = display.events
            let window = try await display.createTopLevelWindow(
                configuration: testWindowConfiguration()
            )

            try await show(window, color: 0x0020_2020)

            let popup = try await window.createPopup(configuration: testPopupConfiguration())
            try await show(popup, color: 0x0040_4040)

            try await expectShownPopup(popup)
            try await redraw(popup, parent: window, events: displayEvents)
            try await close(popup, parent: window, events: displayEvents)

            await window.close()
        }
    }

    @Test
    func hiddenCursorRequestWithoutPointerFocusIsDeterministic() async throws {
        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.PublicIntegration",
            cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
            discoveryTimeoutMilliseconds: publicIntegrationTimeoutMilliseconds
        ) { display in
            let initialCursor = try await display.currentPointerCursor()
            let results = try await display.setPointerCursor(.hidden)
            let finalCursor = try await display.currentPointerCursor()

            #expect(initialCursor == .hidden)
            #expect(results.isEmpty)
            #expect(finalCursor == .hidden)
        }
    }
}

func noteOptionalProtocolSkip(test: String, interfaceName: String) throws {
    try Test.cancel(
        "Compositor did not advertise \(interfaceName) for \(test)."
    )
}

func withPublicConnection(
    _ body: @Sendable (WaylandDisplay) async throws -> Void
) async throws {
    try await WaylandDisplay.withConnection(
        applicationID: "org.waylandclientkit.PublicIntegration",
        cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
        discoveryTimeoutMilliseconds: publicIntegrationTimeoutMilliseconds,
        eventStreamConfiguration: EventStreamConfiguration(
            eventCapacity: try PositiveInt(64),
            inputEventCapacity: try PositiveInt(64),
            dataTransferEventCapacity: try PositiveInt(64)
        ),
        body
    )
}

func testWindowConfiguration() throws -> WindowConfiguration {
    try WindowConfiguration(
        title: "WaylandClientKit Public Integration",
        appID: "wayland-client-kit-public-integration",
        initialWidth: 160,
        initialHeight: 120,
        bufferCount: 3,
        closeRequestPolicy: .requestOnly,
        decorationPreference: .preferServerSide
    )
}

private func testPopupConfiguration() throws -> PopupConfiguration {
    let anchorRect = try LogicalRect(x: 0, y: 0, width: 32, height: 32)
    let popupSize = try PositiveLogicalSize(width: 64, height: 48)

    return PopupConfiguration(
        positioner: PopupPositioner(
            anchorRect: anchorRect,
            size: popupSize,
            anchor: .bottomLeft,
            gravity: .bottomRight,
            constraintAdjustment: [.slideX, .slideY, .flipX, .flipY],
            offset: LogicalOffset(x: 4, y: 4)
        ),
        grab: .none
    )
}

func show(_ window: Window, color: UInt32) async throws {
    let timeout = publicIntegrationTimeoutMilliseconds
    try await window.show(timeoutMilliseconds: timeout, drawColor(color))
}

private func show(_ popup: PopupSurface, color: UInt32) async throws {
    let timeout = publicIntegrationTimeoutMilliseconds
    try await popup.show(timeoutMilliseconds: timeout, drawColor(color))
}

private struct PublicStreamSources: Sendable {
    let displayEvents: DisplayEvents
    let inputEvents: InputEvents
    let dataTransferEvents: DataTransferEvents
    let textInputEvents: TextInputEvents
    let diagnostics: DisplayDiagnostics
}

private func streamCloseResults(
    sources: PublicStreamSources,
    close: @escaping @Sendable () async -> Void
) async throws -> [Bool] {
    try await withTimeout(
        nanoseconds: publicIntegrationWaitTimeoutNanoseconds,
        operation: "closing public event streams"
    ) {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                try await waitForTermination(of: sources.displayEvents)
            }
            group.addTask {
                try await waitForTermination(of: sources.inputEvents)
            }
            group.addTask {
                try await waitForTermination(of: sources.dataTransferEvents)
            }
            group.addTask {
                try await waitForTermination(of: sources.textInputEvents)
            }
            group.addTask {
                try await waitForTermination(of: sources.diagnostics)
            }

            await Task.yield()
            await close()

            var results: [Bool] = []
            while let result = try await group.next() {
                results.append(result)
            }
            return results
        }
    }
}

private func waitForTermination<Stream: AsyncSequence & Sendable>(
    of stream: Stream
) async throws -> Bool {
    var iterator = stream.makeAsyncIterator()
    while try await iterator.next() != nil {
        // Consume queued events before observing stream termination.
    }
    return true
}

func displayEvent(
    in events: DisplayEvents,
    matching predicate: @escaping @Sendable (DisplayEvent) -> Bool,
    after trigger: @escaping @Sendable () async throws -> Void
) async throws -> DisplayEvent {
    try await withTimeout(
        nanoseconds: publicIntegrationWaitTimeoutNanoseconds,
        operation: "waiting for display event"
    ) {
        var iterator = events.makeAsyncIterator()
        try await trigger()

        while let event = try await iterator.next() {
            if predicate(event) {
                return event
            }
        }

        throw PublicIntegrationError.streamEnded
    }
}

private func expectShownPopup(_ popup: PopupSurface) async throws {
    let placement = try await popup.placement
    #expect(placement.size.width.rawValue > 0)
    #expect(placement.size.height.rawValue > 0)
    #expect(try await !popup.isClosed)
}

private func redraw(
    _ popup: PopupSurface,
    parent window: Window,
    events displayEvents: DisplayEvents
) async throws {
    let redrawEvent = try await displayEvent(
        in: displayEvents,
        matching: { event in
            isPopupLifecycleEvent(
                event,
                eventCase: .redrawRequested,
                popup: popup.identity,
                parentWindowID: window.id
            )
        },
        after: {
            try await popup.requestRedraw()
        }
    )

    guard case .popupRedrawRequested(let lifecycleEvent) = redrawEvent else {
        Issue.record("Expected popup redraw event, got \(redrawEvent)")
        return
    }
    #expect(lifecycleEvent.popup == popup.identity)
    #expect(lifecycleEvent.parentWindowID == window.id)
    #expect(try await popup.needsRedraw)

    try await popup.redraw { frame in
        fill(frame, color: 0x0050_5050)
    }
}

private func close(
    _ window: Window,
    events displayEvents: DisplayEvents
) async throws {
    let closeEvent = try await displayEvent(
        in: displayEvents,
        matching: { event in
            event == .windowClosed(window.id)
        },
        after: {
            await window.close()
            await window.close()
        }
    )

    #expect(closeEvent == .windowClosed(window.id))
}

private func close(
    _ popup: PopupSurface,
    parent window: Window,
    events displayEvents: DisplayEvents
) async throws {
    let closeEvent = try await displayEvent(
        in: displayEvents,
        matching: { event in
            isPopupLifecycleEvent(
                event,
                eventCase: .closed,
                popup: popup.identity,
                parentWindowID: window.id
            )
        },
        after: {
            await popup.close()
            await popup.close()
        }
    )

    guard case .popupClosed(let lifecycleEvent) = closeEvent else {
        Issue.record("Expected popup close event, got \(closeEvent)")
        return
    }
    #expect(lifecycleEvent.popup == popup.identity)
    #expect(lifecycleEvent.parentWindowID == window.id)
    #expect(try await popup.isClosed)
}

private enum PopupEventCase {
    case redrawRequested
    case closed
}

private func isPopupLifecycleEvent(
    _ event: DisplayEvent,
    eventCase expectedCase: PopupEventCase,
    popup expectedPopup: PopupSurfaceIdentity,
    parentWindowID expectedParentWindowID: WindowID
) -> Bool {
    let lifecycleEvent: PopupLifecycleEvent
    switch (expectedCase, event) {
    case (.redrawRequested, .popupRedrawRequested(let event)):
        lifecycleEvent = event
    case (.closed, .popupClosed(let event)):
        lifecycleEvent = event
    case (.redrawRequested, _), (.closed, _):
        return false
    }

    return lifecycleEvent.popup == expectedPopup
        && lifecycleEvent.parentWindowID == expectedParentWindowID
}

enum PublicIntegrationEnvironment {
    static var isEnabled: Bool {
        environmentValue("WAYLAND_CLIENT_KIT_ENABLE_PUBLIC_INTEGRATION_TESTS") == "1"
            && environmentValue("WAYLAND_DISPLAY") != nil
    }

    private static func environmentValue(_ key: String) -> String? {
        guard let value = ProcessInfo.processInfo.environment[key],
            !value.isEmpty
        else {
            return nil
        }

        return value
    }
}

enum PublicIntegrationError: Error, CustomStringConvertible {
    case timeout(operation: String)
    case streamEnded

    var description: String {
        switch self {
        case .timeout(let operation):
            "Timed out waiting for public Wayland integration event: \(operation)"
        case .streamEnded:
            "Public Wayland integration stream ended before the expected event"
        }
    }
}

func withTimeout<Value: Sendable>(
    nanoseconds: UInt64,
    operation operationName: String,
    _ body: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask {
            try await body()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: nanoseconds)
            throw PublicIntegrationError.timeout(operation: operationName)
        }

        guard let value = try await group.next() else {
            throw PublicIntegrationError.timeout(operation: operationName)
        }

        group.cancelAll()
        return value
    }
}

func fill(_ frame: borrowing SoftwareFrame, color: UInt32) {
    frame.withXRGB8888Rows { _, pixels in
        for index in 0..<pixels.count {
            pixels[unchecked: index] = color
        }
    }
}

private func drawColor(_ color: UInt32) -> @Sendable (borrowing SoftwareFrame) throws -> Void {
    { frame in
        fill(frame, color: color)
    }
}
