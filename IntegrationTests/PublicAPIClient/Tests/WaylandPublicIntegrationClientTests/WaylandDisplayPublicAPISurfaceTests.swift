import Foundation
import Testing
import WaylandClient

@Suite("WaylandDisplay public API surface")
struct WaylandDisplayPublicAPISurfaceTests {
    @Test
    func primarySelectionPublicTypesCompileForExternalClients() throws {
        let payload = DataTransferSourcePayload(
            mimeType: .plainText,
            data: Data("primary".utf8)
        )
        let configuration = try PrimarySelectionSourceConfiguration(payloads: [payload])

        #expect(configuration.payloads == [payload])
        #expect(
            try PrimarySelectionSourceConfiguration.data(
                mimeType: .plainTextUTF8,
                Data("primary utf8".utf8)
            ).payloads.first?.mimeType == .plainTextUTF8)
    }

    @Test
    func primarySelectionDisplayMethodsCompileForExternalClients() {
        func usePrimarySelectionAPI(
            display: WaylandDisplay,
            seatID: SeatID,
            serial: InputSerial
        ) async throws {
            let configuration = try PrimarySelectionSourceConfiguration.data(
                mimeType: .plainText,
                Data("primary".utf8)
            )
            let source = try await display.requestPrimarySelection(
                configuration,
                seatID: seatID,
                serial: serial
            )
            _ = try await display.primarySelectionOffer(for: seatID)
            try await source.requestClear(serial: serial)
            try await display.requestClearPrimarySelection(seatID: seatID, serial: serial)
        }

        _ = usePrimarySelectionAPI
    }

    @Test
    func capabilityTypesAndDisplayMethodCompileForExternalClients() {
        let availability = ProtocolAvailability.available(version: 1)
        let capabilities = WaylandCapabilities(
            clipboard: availability,
            primarySelection: .unavailable,
            xdgDecoration: .available(version: 2),
            viewporter: .available(version: 1),
            fractionalScale: .unavailable
        )

        #expect(availability.isAvailable)
        #expect(availability.version == 1)
        #expect(capabilities.clipboard == .available(version: 1))
        #expect(capabilities.primarySelection == .unavailable)

        func useCapabilitiesAPI(display: WaylandDisplay) async throws -> WaylandCapabilities {
            try await display.capabilities()
        }

        _ = useCapabilitiesAPI
    }

    @Test
    func outputSnapshotTypesAndDisplayMethodCompileForExternalClients() throws {
        let scale = try PositiveInt32(2)
        let snapshot = OutputSnapshot(
            id: OutputID(rawValue: 1),
            version: 4,
            geometry: OutputGeometry(
                x: 0,
                y: 0,
                physicalWidthMillimeters: 600,
                physicalHeightMillimeters: 340,
                subpixel: 1,
                make: "Acme",
                model: "Panel",
                transform: 0
            ),
            currentMode: OutputMode(
                flags: 1,
                width: 1_920,
                height: 1_080,
                refreshMilliHertz: 60_000
            ),
            scale: scale,
            name: "HDMI-A-1",
            description: "Acme Panel"
        )

        #expect(snapshot.id == OutputID(rawValue: 1))
        #expect(snapshot.scale == scale)

        func useOutputsAPI(display: WaylandDisplay) async throws -> [OutputSnapshot] {
            try await display.outputs()
        }

        _ = useOutputsAPI
    }

    @Test
    func windowManagerControlMethodsCompileForExternalClients() throws {
        let minimumSize = try PositiveLogicalSize(width: 320, height: 240)
        let maximumSize = try PositiveLogicalSize(width: 1_920, height: 1_080)
        let snapshot = WindowStateSnapshot(
            configureSerial: 10,
            size: minimumSize,
            states: [.activated, .tiled(.left)],
            bounds: maximumSize,
            managerCapabilities: [.maximize, .fullscreen],
            decorationMode: .serverSide,
            outputs: [OutputID(rawValue: 1)]
        )

        #expect(snapshot.configureSerial == 10)
        #expect(snapshot.outputs == [OutputID(rawValue: 1)])
        #expect(WindowResizeEdge.bottomRight == .bottomRight)

        func useWindowControls(window: Window, seatID: SeatID, serial: InputSerial) async throws {
            try await window.setTitle("Settings")
            try await window.setAppID("com.example.settings")
            try await window.setMinimumSize(minimumSize)
            try await window.setMaximumSize(maximumSize)
            try await window.setMinimumSize(nil)
            try await window.requestMaximize()
            try await window.requestUnmaximize()
            try await window.requestFullscreen()
            try await window.requestFullscreen(output: OutputID(rawValue: 1))
            try await window.requestExitFullscreen()
            try await window.requestMinimize()
            try await window.requestInteractiveMove(seatID: seatID, serial: serial)
            try await window.requestInteractiveResize(
                seatID: seatID,
                serial: serial,
                edge: .bottomRight
            )
            try await window.requestWindowMenu(
                seatID: seatID,
                serial: serial,
                position: LogicalOffset(x: 8, y: 12)
            )
            _ = try await window.stateSnapshot
        }

        _ = useWindowControls
    }

    @Test
    func primarySelectionDataTransferEventsCompileForExternalClients() {
        func consumeDataTransferEvent(_ event: DataTransferEvent) -> String {
            switch event {
            case .clipboardSelectionChanged(let event):
                event.offer?.description ?? "clipboard cleared"
            case .primarySelectionChanged(let event):
                event.offer?.description ?? "primary selection cleared"
            case .clipboardSourceCancelled(let identity):
                identity.description
            case .primarySelectionSourceCancelled(let identity):
                identity.description
            }
        }

        _ = consumeDataTransferEvent
    }
}
