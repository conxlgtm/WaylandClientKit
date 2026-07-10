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
            presentationTime: .unavailable,
            fractionalScale: .unavailable,
            cursorShape: .available(version: 1),
            xdgActivation: .unavailable,
            relativePointer: .available(version: 1),
            pointerConstraints: .available(version: 1),
            textInput: .unavailable,
            linuxDmabuf: .available(version: 5)
        )

        #expect(availability.isAvailable)
        #expect(availability.version == 1)
        #expect(capabilities.clipboard == .available(version: 1))
        #expect(capabilities.dragAndDrop == .available(version: 1))
        #expect(capabilities.dragActionNegotiation == .unavailable)
        #expect(capabilities.primarySelection == .unavailable)
        #expect(capabilities.xdgOutput == .available(version: 3))
        #expect(capabilities.presentationTime == .unavailable)
        #expect(capabilities.cursorShape == .available(version: 1))
        #expect(capabilities.xdgActivation == .unavailable)
        #expect(capabilities.relativePointer == .available(version: 1))
        #expect(capabilities.pointerConstraints == .available(version: 1))
        #expect(capabilities.textInput == .unavailable)
        #expect(capabilities.linuxDmabuf == .available(version: 5))

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
    func previewProtocolTypesAndDisplayMethodsCompileForExternalClients() throws {
        let foreignSnapshot = ForeignToplevelSnapshot(
            id: ForeignToplevelID(rawValue: 1),
            protocolIdentifier: "foreign-1",
            title: nil,
            appID: nil
        )
        let foreignList = ForeignToplevelListSnapshot(
            toplevels: [foreignSnapshot],
            events: [.added(foreignSnapshot), .removed(foreignSnapshot.id)]
        )
        let outputMode = OutputManagementMode(
            id: OutputManagementModeID(rawValue: 1),
            size: try PositivePixelSize(width: 1_920, height: 1_080),
            refresh: .milliHertz(try PositiveInt32(60_000)),
            isPreferred: true,
            isCurrent: true
        )
        let outputHead = OutputManagementHead(
            id: OutputManagementHeadID(rawValue: 1),
            name: "HDMI-A-1",
            description: "Display",
            modes: [outputMode],
            enabled: true,
            position: .zero,
            scale: .one,
            transform: .normal,
            make: nil,
            model: nil,
            serialNumber: nil
        )
        let outputSnapshot = OutputManagementSnapshot(heads: [outputHead], serial: 7)
        let sessionID = try CompositorSessionID("session-1")
        let sessionSnapshot = CompositorSessionEventSnapshot(
            events: [.created(sessionID), .restored, .replaced]
        )

        #expect(foreignList.toplevels == [foreignSnapshot])
        #expect(outputSnapshot.heads.first?.modes == [outputMode])
        #expect(sessionSnapshot.events.count == 3)

        func usePreviewProtocolAPI(display: WaylandDisplay) async throws {
            _ = try await display.foreignToplevelListSnapshot()
            _ = try await display.outputManagementSnapshot()
            _ = try await display.compositorSessionEvents(
                reason: .launch,
                existingID: sessionID
            )
        }

        _ = usePreviewProtocolAPI
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
}

@Suite("WaylandDisplay presentation public API surface")
struct WaylandPresentationAPISurfaceTests {
    @Test
    func presentationFeedbackTypesCompileForExternalClients() throws {
        let identity = SurfacePresentationIdentity(rawValue: 9)
        let feedback = PresentationFeedback(
            surface: identity,
            timestamp: PresentationTimestamp(seconds: 12, nanoseconds: 345),
            refreshNanoseconds: 16_666_667,
            sequence: PresentationSequence(value: 99),
            flags: [.vsync, .hardwareClock],
            synchronizedOutput: OutputID(rawValue: 3)
        )
        let event = SurfacePresentationFeedback.presented(feedback)

        #expect(identity.description == "presentation-9")
        #expect(feedback.surface == identity)
        #expect(feedback.flags.contains(.vsync))
        #expect(event == .presented(feedback))
        #expect(SurfacePresentationFeedback.discarded(identity) == .discarded(identity))

        func usePresentationFeedbackAPI(window: Window) async throws {
            let events = window.presentationEvents
            _ = events.makeAsyncIterator()
            try await window.requestPresentationFeedback()
        }

        _ = usePresentationFeedbackAPI
    }
}

@Suite("WaylandDisplay data transfer public API surface")
struct WaylandDataTransferAPISurfaceTests {
    @Test
    func primarySelectionDataTransferEventsCompileForExternalClients() {
        // swiftlint:disable:next cyclomatic_complexity
        func consumeDataTransferEvent(_ event: DataTransferEvent) -> String {
            switch event {
            case .clipboardSelectionChanged(let event):
                event.offer?.description ?? "clipboard cleared"
            case .primarySelectionChanged(let event):
                event.offer?.description ?? "primary selection cleared"
            case .sourceSendRequested(let event):
                "\(event.source.description):\(event.mimeType.description)"
            case .sourceWriteSucceeded(let event):
                "\(event.source.description):\(event.mimeType.description)"
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
            case .dragSourceFinished(let event):
                "\(event.source.description):\(event.finalAction.description)"
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
        #expect(
            try DragIcon.xrgb8888(
                DragIconImage(
                    size: PositivePixelSize(
                        width: try PositiveInt32(1),
                        height: try PositiveInt32(1)
                    ),
                    pixels: [0x00ff_ffff]
                )
            ) != .none
        )

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

@Suite("WaylandDisplay text-input public API surface")
struct WaylandTextInputAPISurfaceTests {
    @Test
    func textInputTypesCompileForExternalClients() throws {
        let hints: TextInputContentHints = [.completion, .spellcheck, .preeditShown]
        let purpose = TextInputContentPurpose.email
        let preeditHint = TextInputPreeditHint(
            start: 0,
            end: 3,
            kind: .prediction
        )
        let seatID = SeatID(rawValue: 3)
        let event = TextInputEvent.preedit(
            TextInputPreeditEvent(
                seatID: seatID,
                text: "pre",
                cursorBegin: 0,
                cursorEnd: 3,
                hints: [preeditHint]
            )
        )

        #expect(hints.contains(.completion))
        #expect(purpose == .email)
        #expect(TextInputChangeCause.other.rawValue == 1)
        #expect(TextInputAction.submit.rawValue == 1)
        #expect(
            event
                == .preedit(
                    TextInputPreeditEvent(
                        seatID: seatID,
                        text: "pre",
                        cursorBegin: 0,
                        cursorEnd: 3,
                        hints: [preeditHint]
                    )
                )
        )

        func useTextInputAPI(
            display: WaylandDisplay,
            window: Window,
            rect: LogicalRect
        ) async throws {
            let session = try await display.textInputSession(for: seatID)
            var iterator = display.textInputEvents.makeAsyncIterator()
            try await session.enable(for: window)
            try await session.setSurroundingText(
                TextInputSurroundingText(
                    text: "hello",
                    cursorUTF8Offset: 5,
                    anchorUTF8Offset: 0
                )
            )
            try await session.setTextChangeCause(.other)
            try await session.setContentType(hints: hints, purpose: purpose)
            try await session.setCursorRectangle(rect)
            try await session.commit()
            try await session.disable()
            _ = try await iterator.next()
        }

        _ = useTextInputAPI
    }
}
