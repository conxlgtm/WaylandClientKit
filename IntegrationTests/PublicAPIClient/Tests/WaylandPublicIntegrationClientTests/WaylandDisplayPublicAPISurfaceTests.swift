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
            dragAndDrop: availability,
            dragActionNegotiation: .unavailable,
            primarySelection: .unavailable,
            xdgDecoration: .available(version: 2),
            xdgOutput: .available(version: 3),
            viewporter: .available(version: 1),
            fractionalScale: .unavailable
        )

        #expect(availability.isAvailable)
        #expect(availability.version == 1)
        #expect(capabilities.clipboard == .available(version: 1))
        #expect(capabilities.dragAndDrop == .available(version: 1))
        #expect(capabilities.dragActionNegotiation == .unavailable)
        #expect(capabilities.primarySelection == .unavailable)
        #expect(capabilities.xdgOutput == .available(version: 3))

        func useCapabilitiesAPI(display: WaylandDisplay) async throws -> WaylandCapabilities {
            try await display.capabilities()
        }

        _ = useCapabilitiesAPI
    }

    @Test
    func outputSnapshotTypesAndDisplayMethodCompileForExternalClients() throws {
        let scale = try PositiveInt32(2)
        let logicalWidth = try PositiveInt32(1_280)
        let logicalHeight = try PositiveInt32(720)
        let snapshot = OutputSnapshot(
            id: OutputID(rawValue: 1),
            version: 4,
            geometry: OutputGeometry(
                x: 0,
                y: 0,
                physicalWidthMillimeters: 600,
                physicalHeightMillimeters: 340,
                subpixel: .none,
                make: "Acme",
                model: "Panel",
                transform: .normal
            ),
            logicalGeometry: OutputLogicalGeometry(
                x: 1_920,
                y: 0,
                width: logicalWidth,
                height: logicalHeight
            ),
            currentMode: OutputMode(
                flags: [.current],
                width: try PositiveInt32(1_920),
                height: try PositiveInt32(1_080),
                refresh: .milliHertz(try PositiveInt32(60_000))
            ),
            scale: scale,
            name: "HDMI-A-1",
            description: "Acme Panel"
        )

        #expect(snapshot.id == OutputID(rawValue: 1))
        #expect(snapshot.scale == scale)
        #expect(snapshot.logicalGeometry?.width == logicalWidth)
        #expect(OutputSubpixelLayout(rawValue: 999) == .unrecognized(999))
        #expect(OutputTransform(rawValue: 999) == .unrecognized(999))
        #expect(OutputModeFlags.preferred.rawValue == 0x2)

        func useOutputsAPI(display: WaylandDisplay) async throws -> [OutputSnapshot] {
            try await display.outputs()
        }

        func consumeOutputDisplayEvent(_ event: DisplayEvent) -> String? {
            switch event {
            case .outputChanged(let snapshot):
                snapshot.name ?? snapshot.id.description
            case .outputRemoved(let id):
                id.description
            case .windowOutputsChanged(let event):
                "\(event.windowID):\(event.outputs.count)"
            default:
                nil
            }
        }

        _ = useOutputsAPI
        _ = consumeOutputDisplayEvent
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
        // swiftlint:disable:next cyclomatic_complexity
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
            case .dragSourceCancelled(let identity):
                identity.description
            case .dragSourceTargetChanged(let event):
                event.mimeType?.description ?? event.source.description
            case .dragSourceActionChanged(let event):
                "\(event.source.description):\(event.action.description)"
            case .dragSourceDropPerformed(let identity):
                identity.description
            case .dragSourceFinished(let identity):
                identity.description
            case .dragEntered(let event):
                "\(event.offer.description):\(event.serial.description):\(event.target)"
            case .dragMotion(let event):
                "\(event.offer.description):\(event.time.description)"
            case .dragLeft(let event):
                event.offer.description
            case .dragDropped(let event):
                event.offer.description
            case .dragOfferChanged(let event):
                event.offer.description
            }
        }

        _ = consumeDataTransferEvent
    }

    @Test
    func dragAndDropPublicTypesCompileForExternalClients() throws {
        let actions: DragActionSet = [.copy, .move]
        let payload = DataTransferSourcePayload(
            mimeType: .plainText,
            data: Data("drag".utf8)
        )
        let sourceConfiguration = try DragSourceConfiguration(
            payloads: [payload],
            actions: actions
        )

        #expect(actions.contains(.copy))
        #expect(DragAction.ask.description == "ask")
        #expect(sourceConfiguration.payloads == [payload])
        #expect(DragIcon.none == .none)

        func useDragAndDropAPI(
            display: WaylandDisplay,
            window: Window,
            seatID: SeatID,
            serial: InputSerial
        ) async throws {
            guard let offer = try await display.dragOffer(for: seatID) else {
                return
            }

            let source = try await window.startDrag(
                source: sourceConfiguration,
                seatID: seatID,
                serial: serial
            )
            _ = source.identity.description
            try await source.cancel()
            try await offer.accept(.plainText)
            try await offer.setActions([.copy, .move], preferredAction: .copy)
            _ = try await offer.receive(.plainText)
            _ = try await offer.read(.plainText)
            try await offer.finish()
            try await offer.cancel()
        }

        _ = useDragAndDropAPI
    }
}
