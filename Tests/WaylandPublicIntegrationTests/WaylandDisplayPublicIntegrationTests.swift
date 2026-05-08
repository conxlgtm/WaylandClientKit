import Foundation
import Testing
import WaylandClient

private let publicIntegrationTimeoutMilliseconds: Int32 = 5_000
private let publicIntegrationWaitTimeoutNanoseconds: UInt64 = 5_000_000_000

@Suite(
    "WaylandDisplay public integration",
    .enabled(
        if: PublicIntegrationEnvironment.isEnabled,
        "Set WAYLAND_DISPLAY and SWIFT_WAYLAND_ENABLE_PUBLIC_INTEGRATION_TESTS=1"
    ),
    .serialized
)
struct WaylandDisplayPublicIntegrationTests {
    @Test
    func connectionCloseFinishesPublicStreams() async throws {
        try await withPublicConnection { display in
            let displayEvents = display.events
            let inputEvents = display.inputEvents
            let dataTransferEvents = display.dataTransferEvents
            let diagnostics = display.diagnostics

            let streamResults = try await streamCloseResults(
                displayEvents: displayEvents,
                inputEvents: inputEvents,
                dataTransferEvents: dataTransferEvents,
                diagnostics: diagnostics
            ) {
                await display.close()
            }

            #expect(streamResults.count == 4)
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
            #expect(try await !window.needsRedraw)

            await window.close()
            await window.close()
            #expect(try await window.isClosed)
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

private func withPublicConnection(
    _ body: @Sendable (WaylandDisplay) async throws -> Void
) async throws {
    try await WaylandDisplay.withConnection(
        cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
        discoveryTimeoutMilliseconds: publicIntegrationTimeoutMilliseconds,
        eventStreamConfiguration: try EventStreamConfiguration(
            displayEventCapacity: 64,
            inputEventCapacity: 64,
            dataTransferEventCapacity: 64
        ),
        body
    )
}

private func testWindowConfiguration() throws -> WindowConfiguration {
    try WindowConfiguration(
        title: "SwiftWayland Public Integration",
        appID: "swift-wayland-public-integration",
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

private func show(_ window: Window, color: UInt32) async throws {
    let timeout = publicIntegrationTimeoutMilliseconds
    try await window.show(timeoutMilliseconds: timeout, drawColor(color))
}

private func show(_ popup: PopupSurface, color: UInt32) async throws {
    let timeout = publicIntegrationTimeoutMilliseconds
    try await popup.show(timeoutMilliseconds: timeout, drawColor(color))
}

private func nextDisplayEvent(
    in events: DisplayEvents,
    matching predicate: @escaping @Sendable (DisplayEvent) -> Bool
) async throws -> DisplayEvent {
    var iterator = events.makeAsyncIterator()
    while let event = try await iterator.next() {
        if predicate(event) {
            return event
        }
    }

    throw PublicIntegrationError.streamEnded
}

private func streamCloseResults(
    displayEvents: DisplayEvents,
    inputEvents: InputEvents,
    dataTransferEvents: DataTransferEvents,
    diagnostics: DisplayDiagnostics,
    close: @escaping @Sendable () async -> Void
) async throws -> [Bool] {
    try await withTimeout(nanoseconds: publicIntegrationWaitTimeoutNanoseconds) {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = displayEvents.makeAsyncIterator()
                return try await iterator.next() == nil
            }
            group.addTask {
                var iterator = inputEvents.makeAsyncIterator()
                return try await iterator.next() == nil
            }
            group.addTask {
                var iterator = dataTransferEvents.makeAsyncIterator()
                return try await iterator.next() == nil
            }
            group.addTask {
                var iterator = diagnostics.makeAsyncIterator()
                return try await iterator.next() == nil
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

private func displayEvent(
    in events: DisplayEvents,
    matching predicate: @escaping @Sendable (DisplayEvent) -> Bool,
    after trigger: @escaping @Sendable () async throws -> Void
) async throws -> DisplayEvent {
    try await withTimeout(nanoseconds: publicIntegrationWaitTimeoutNanoseconds) {
        try await withThrowingTaskGroup(of: DisplayEvent.self) { group in
            group.addTask {
                try await nextDisplayEvent(in: events, matching: predicate)
            }

            await Task.yield()
            try await trigger()

            guard let event = try await group.next() else {
                throw PublicIntegrationError.streamEnded
            }
            group.cancelAll()
            return event
        }
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
    #expect(try await !popup.needsRedraw)
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

private enum PublicIntegrationEnvironment {
    static var isEnabled: Bool {
        environmentValue("SWIFT_WAYLAND_ENABLE_PUBLIC_INTEGRATION_TESTS") == "1"
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

private enum PublicIntegrationError: Error, CustomStringConvertible {
    case timeout
    case streamEnded

    var description: String {
        switch self {
        case .timeout:
            "Timed out waiting for public Wayland integration event"
        case .streamEnded:
            "Public Wayland integration stream ended before the expected event"
        }
    }
}

private func withTimeout<Value: Sendable>(
    nanoseconds: UInt64,
    _ operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: nanoseconds)
            throw PublicIntegrationError.timeout
        }

        guard let value = try await group.next() else {
            throw PublicIntegrationError.timeout
        }

        group.cancelAll()
        return value
    }
}

private func fill(_ frame: borrowing SoftwareFrame, color: UInt32) {
    frame.withXRGB8888Rows { _, pixels in
        for index in 0..<pixels.count {
            pixels[unchecked: index] = color
        }
    }
}

private func drawColor(
    _ color: UInt32
) -> @Sendable (borrowing SoftwareFrame) throws -> Void {
    { frame in
        fill(frame, color: color)
    }
}
