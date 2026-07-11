import Foundation
import Testing
import WaylandClient
import WaylandGraphicsPreview

@Suite
struct WaylandFrameworkHostClientTests {
    @Test
    func frameworkHostPublicTypesCoverWindowEventAndGraphicsBoundaries() throws {
        let streams = try EventStreamConfiguration(
            displayEventCapacity: 32,
            inputEventCapacity: 32,
            textInputEventCapacity: 16,
            dataTransferEventCapacity: 16,
            presentationEventCapacity: 16
        )
        let displayConfiguration = try DisplayConfiguration(
            applicationID: "org.waylandclientkit.FrameworkHostIntegration",
            eventStreams: streams
        )
        let windowConfiguration = try WindowConfiguration(
            title: "Framework Host Client",
            appID: "framework-host-client",
            initialWidth: 128,
            initialHeight: 96,
            bufferCount: 3,
            closeRequestPolicy: .requestOnly,
            decorationPreference: .preferServerSide
        )
        let popupConfiguration = try PopupConfiguration(
            positioner: PopupPositioner(
                anchorRect: LogicalRect(x: 0, y: 0, width: 32, height: 32),
                size: PositiveLogicalSize(width: 64, height: 48),
                anchor: .bottomLeft,
                gravity: .bottomRight,
                constraintAdjustment: [.slideX, .slideY]
            )
        )
        let graphicsConfiguration = WaylandGraphicsConfiguration(
            presentationPolicy: .software,
            synchronizationPolicy: .implicitOnly,
            pacingPolicy: .none,
            metadataPolicy: .preferAvailable,
            presentationFeedbackPolicy: .requestWhenAvailable
        )
        let damage = WaylandGraphicsDamageRegion(rects: [])
        let metadata = WaylandGraphicsFrameMetadata(damage: damage)

        #expect(displayConfiguration.eventStreams == streams)
        #expect(windowConfiguration.initialSize.width.rawValue == 128)
        #expect(popupConfiguration.positioner.size.width.rawValue == 64)
        #expect(graphicsConfiguration.presentationPolicy == .software)
        #expect(metadata.damage == .fullFrame)
    }

    @Test
    func frameworkHostLoopShapeUsesOnlyPublicAPIs() async throws {
        func hostLoop(display: WaylandDisplay) async throws {
            let capabilities = try await display.capabilities()
            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "Framework Host Client",
                    appID: "framework-host-client",
                    initialWidth: 64,
                    initialHeight: 64
                )
            )
            let popup = try await window.createPopup(
                configuration: try PopupConfiguration(
                    positioner: PopupPositioner(
                        anchorRect: LogicalRect(x: 0, y: 0, width: 16, height: 16),
                        size: PositiveLogicalSize(width: 32, height: 32)
                    )
                )
            )

            _ = display.events
            _ = display.inputEvents
            _ = display.textInputEvents
            _ = display.dataTransferEvents
            _ = display.diagnostics
            _ = window.presentationEvents
            _ = capabilities.dragAndDrop
            _ = try await window.geometry
            _ = try await window.needsRedraw
            _ = try await popup.placement

            try await window.requestRedraw()
            try await window.show { frame in
                fill(frame, color: 0x0010_2030)
            }
            try await window.redraw { frame in
                fill(frame, color: 0x0030_2010)
            }

            if capabilities.dragAndDrop.isAvailable {
                let source = try await window.startDrag(
                    source: DragSourceConfiguration(
                        payloads: [
                            DataTransferSourcePayload(
                                mimeType: .plainText,
                                data: Data("framework-host".utf8)
                            )
                        ],
                        actions: .copy
                    ),
                    seatID: SeatID(rawValue: 1),
                    serial: InputSerial(rawValue: 1)
                )
                try await source.cancel()
            }

            await popup.close()
            await window.close()
        }

        _ = hostLoop
    }

    @Test(
        .enabled(
            if: FrameworkHostEnvironment.liveWaylandEnabled,
            "Set WAYLAND_DISPLAY and WAYLAND_CLIENT_KIT_ENABLE_FRAMEWORK_HOST_TESTS=1"
        ),
        .timeLimit(.minutes(1))
    )
    func liveHeadlessHostPathCreatesWindowAndQueriesGraphicsFacts() async throws {
        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.FrameworkHostIntegration",
            cursorConfiguration: CursorConfiguration(fallbackCursor: .hidden),
            discoveryTimeoutMilliseconds: 5_000,
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 64,
                textInputEventCapacity: 32,
                dataTransferEventCapacity: 32,
                presentationEventCapacity: 32
            )
        ) { display in
            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "Framework Host Client",
                    appID: "framework-host-client",
                    initialWidth: 96,
                    initialHeight: 72,
                    closeRequestPolicy: .requestOnly
                )
            )

            try await window.show { frame in
                fill(frame, color: 0x0020_3040)
            }
            let geometry = try await window.geometry
            #expect(geometry.bufferSize.width.rawValue > 0)
            #expect(try await !window.isClosed)

            _ = try await display.capabilities()
            _ = try await display.graphicsSurfaceCapabilities()
            _ = try await display.graphicsRuntimePath(policy: .software)
            _ = try await display.graphicsBackingDecision(
                policy: .managedGPU(fallback: .unavailable)
            )

            try await window.requestRedraw()
            if try await window.needsRedraw {
                try await window.redraw { frame in
                    fill(frame, color: 0x0040_3020)
                }
            }

            await window.close()
        }
    }
}

enum FrameworkHostEnvironment {
    static var liveWaylandEnabled: Bool {
        ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"]?.isEmpty == false
            && ProcessInfo.processInfo.environment[
                "WAYLAND_CLIENT_KIT_ENABLE_FRAMEWORK_HOST_TESTS"
            ] == "1"
    }
}

func fill(_ frame: borrowing SoftwareFrame, color: UInt32) {
    frame.withXRGB8888Rows { _, pixels in
        for index in 0..<pixels.count {
            pixels[unchecked: index] = color
        }
    }
}
