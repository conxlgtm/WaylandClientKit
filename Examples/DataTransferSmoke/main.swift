import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum DataTransferSmoke {
    nonisolated private static let leftButton = PointerButtonCode(rawValue: 0x110)
    nonisolated private static let rightButton = PointerButtonCode(rawValue: 0x111)

    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            applicationID: "org.waylandclientkit.DataTransferSmoke",
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 128,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 4_096,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            log("feature: data-transfer")
            log("capability: clipboard \(availabilityDescription(capabilities.clipboard))")
            log("capability: drag \(availabilityDescription(capabilities.dragAndDrop))")
            log("capability: primary \(availabilityDescription(capabilities.primarySelection))")
            log("clipboard capability \(availabilityDescription(capabilities.clipboard))")
            log("drag capability \(availabilityDescription(capabilities.dragAndDrop))")
            log("primary capability \(availabilityDescription(capabilities.primarySelection))")
            log("source readiness text/plain;charset=utf-8,text/plain")

            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Data Transfer Smoke",
                    appID: "wayland-client-kit-data-transfer-smoke",
                    initialWidth: 360,
                    initialHeight: 220,
                    closeRequestPolicy: .requestOnly
                )
            )
            let state = DataTransferSmokeState()
            try await showInitialFrame(window: window, state: state)

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await consumeDisplayEvents(display.events, window: window, state: state)
                }
                group.addTask {
                    try await consumeInputEvents(
                        display.inputEvents,
                        display: display,
                        window: window,
                        state: state
                    )
                }
                group.addTask {
                    try await consumeDataTransferEvents(
                        display.dataTransferEvents,
                        display: display,
                        window: window,
                        state: state
                    )
                }
                group.addTask {
                    try await consumeDiagnostics(display.diagnostics)
                }
                if let seconds = options.autoCloseSeconds {
                    group.addTask {
                        try await Task.sleep(for: .seconds(seconds))
                        await window.close()
                    }
                }

                _ = try await group.next()
                group.cancelAll()
            }

            if options.printSummary {
                log(await state.summary())
            }
            log("result: pass")
            log("cleanup: pass")
        }
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        window: Window,
        state: DataTransferSmokeState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == window.id:
                try await redrawIfNeeded(window: window, state: state)
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

    nonisolated private static func consumeInputEvents(
        _ events: InputEvents,
        display: WaylandDisplay,
        window: Window,
        state: DataTransferSmokeState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard event.windowID == window.id else { continue }

            switch event.kind {
            case .pointer(.button(let button)) where button.state == .pressed:
                if button.button == rightButton {
                    await startDragSource(
                        window: window,
                        seatID: event.seatID,
                        serial: button.serial,
                        state: state
                    )
                } else if button.button == leftButton {
                    await publishClipboardSelection(
                        display: display,
                        seatID: event.seatID,
                        serial: button.serial,
                        state: state
                    )
                }
                try await window.requestRedraw()
            case .keyboard(.interpreted(.key(let key)))
            where key.state == .pressed && isClipboardPublishKey(key):
                await publishClipboardSelection(
                    display: display,
                    seatID: event.seatID,
                    serial: key.serial,
                    state: state
                )
                try await window.requestRedraw()
            default:
                break
            }
        }
    }

    nonisolated private static func isClipboardPublishKey(
        _ key: InterpretedKeyboardKeyEvent
    ) -> Bool {
        if key.utf8?.lowercased() == "c" {
            return true
        }
        return key.keysymName?.lowercased() == "c"
    }

    nonisolated private static func consumeDataTransferEvents(
        _ events: DataTransferEvents,
        display: WaylandDisplay,
        window: Window,
        state: DataTransferSmokeState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            await state.record(event)
            if shouldLogDataTransferEvent(event) {
                log("data-transfer event \(dataTransferDescription(event))")
            }

            switch event {
            case .clipboardSelectionChanged(let selection):
                await readClipboardSelection(selection, display: display, state: state)
            case .primarySelectionChanged:
                break
            case .dragEntered(let enter):
                await acceptDragOffer(enter.seatID, display: display)
            case .dragOfferChanged(let change):
                await acceptDragOffer(change.seatID, display: display)
            case .dragDropped(let drop):
                await readDroppedDragOffer(drop.seatID, display: display, state: state)
            case .dragLeft(let leave):
                await cancelDragOffer(leave.seatID, display: display)
            case .sourceSendRequested, .sourceWriteSucceeded, .clipboardSourceCancelled,
                .primarySelectionSourceCancelled,
                .dragSourceCancelled, .dragSourceTargetChanged, .dragSourceActionChanged,
                .dragSourceDropPerformed, .dragSourceFinished, .dragMotion:
                break
            }

            switch event {
            case .sourceSendRequested, .sourceWriteSucceeded, .clipboardSourceCancelled,
                .primarySelectionSourceCancelled, .dragSourceCancelled,
                .dragSourceTargetChanged, .dragSourceActionChanged,
                .dragSourceDropPerformed, .dragSourceFinished:
                try await window.requestRedraw()
            case .clipboardSelectionChanged, .primarySelectionChanged, .dragEntered,
                .dragMotion, .dragLeft, .dragDropped, .dragOfferChanged:
                break
            }
        }
    }

    nonisolated private static func shouldLogDataTransferEvent(
        _ event: DataTransferEvent
    ) -> Bool {
        switch event {
        case .primarySelectionChanged:
            false
        case .clipboardSelectionChanged, .sourceSendRequested, .sourceWriteSucceeded,
            .clipboardSourceCancelled, .primarySelectionSourceCancelled,
            .dragSourceCancelled, .dragSourceTargetChanged, .dragSourceActionChanged,
            .dragSourceDropPerformed, .dragSourceFinished, .dragEntered, .dragMotion,
            .dragLeft, .dragDropped, .dragOfferChanged:
            true
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

    nonisolated private static func publishClipboardSelection(
        display: WaylandDisplay,
        seatID: SeatID,
        serial: InputSerial,
        state: DataTransferSmokeState
    ) async {
        do {
            let payloads = transferPayloads(label: "selection", serial: serial)
            let clipboard = try await display.requestClipboardSelection(
                ClipboardSourceConfiguration(payloads: payloads),
                seatID: seatID,
                serial: serial
            )
            await state.recordClipboardSource(clipboard)
            log("operation: request-clipboard-source pass")
            log("clipboard source requested seat=\(seatID) serial=\(serial)")
        } catch {
            log("operation: request-clipboard-source failed")
            log("clipboard source request failed seat=\(seatID) serial=\(serial) error=\(error)")
        }
    }

    nonisolated private static func startDragSource(
        window: Window,
        seatID: SeatID,
        serial: InputSerial,
        state: DataTransferSmokeState
    ) async {
        do {
            let configuration = try DragSourceConfiguration(
                payloads: transferPayloads(label: "drag", serial: serial),
                actions: [.copy]
            )
            let source = try await window.startDrag(
                source: configuration,
                seatID: seatID,
                serial: serial,
                icon: .none
            )
            await state.recordSource("drag \(source.identity)")
            log("operation: start-drag-source pass")
            log("drag source started seat=\(seatID) serial=\(serial)")
        } catch {
            log("operation: start-drag-source failed")
            log("drag source failed seat=\(seatID) serial=\(serial) error=\(error)")
        }
    }

    nonisolated private static func readClipboardSelection(
        _ selection: ClipboardSelectionEvent,
        display: WaylandDisplay,
        state: DataTransferSmokeState
    ) async {
        guard selection.offer != nil else {
            log("clipboard cleared seat=\(selection.seatID)")
            return
        }

        do {
            guard let offer = try await display.clipboardOffer(for: selection.seatID) else {
                log("clipboard offer became unavailable seat=\(selection.seatID)")
                return
            }
            try await readOffer(
                label: "clipboard \(offer.identity)",
                mimeTypes: offer.mimeTypes,
                state: state
            ) { mimeType, limit, timeout in
                try await offer.read(mimeType, limit: limit, timeout: timeout)
            }
        } catch {
            log("clipboard offer read skipped seat=\(selection.seatID) error=\(error)")
        }
    }

    nonisolated private static func readPrimarySelection(
        _ selection: PrimarySelectionEvent,
        display: WaylandDisplay,
        state: DataTransferSmokeState
    ) async {
        guard selection.offer != nil else {
            log("primary selection cleared seat=\(selection.seatID)")
            return
        }

        do {
            guard let offer = try await display.primarySelectionOffer(for: selection.seatID) else {
                log("primary offer became unavailable seat=\(selection.seatID)")
                return
            }
            try await readOffer(
                label: "primary \(offer.identity)",
                mimeTypes: offer.mimeTypes,
                state: state
            ) { mimeType, limit, timeout in
                try await offer.read(mimeType, limit: limit, timeout: timeout)
            }
        } catch {
            log("primary offer read skipped seat=\(selection.seatID) error=\(error)")
        }
    }

    nonisolated private static func acceptDragOffer(
        _ seatID: SeatID,
        display: WaylandDisplay
    ) async {
        do {
            guard let offer = try await display.dragOffer(for: seatID) else {
                log("drag offer became unavailable seat=\(seatID)")
                return
            }
            logFilteredMIMEs(label: "drag \(offer.identity)", mimeTypes: offer.mimeTypes)
            let mimeType = preferredMIMEType(from: offer.mimeTypes)
            try await offer.accept(mimeType)
            if mimeType != nil {
                do {
                    try await offer.setActions(.copy, preferredAction: .copy)
                } catch {
                    log("drag action negotiation skipped offer=\(offer.identity) error=\(error)")
                }
            }
        } catch {
            log("drag offer accept skipped seat=\(seatID) error=\(error)")
        }
    }

    nonisolated private static func readDroppedDragOffer(
        _ seatID: SeatID,
        display: WaylandDisplay,
        state: DataTransferSmokeState
    ) async {
        do {
            guard let offer = try await display.dragOffer(for: seatID) else {
                log("drag drop had no active offer seat=\(seatID)")
                return
            }
            try await readOffer(
                label: "drag \(offer.identity)",
                mimeTypes: offer.mimeTypes,
                state: state
            ) { mimeType, limit, timeout in
                try await offer.read(mimeType, limit: limit, timeout: timeout)
            }
            try await offer.finish()
        } catch {
            log("drag drop read/finish failed seat=\(seatID) error=\(error)")
            await cancelDragOffer(seatID, display: display)
        }
    }

    nonisolated private static func cancelDragOffer(
        _ seatID: SeatID,
        display: WaylandDisplay
    ) async {
        do {
            guard let offer = try await display.dragOffer(for: seatID) else { return }
            try await offer.cancel()
        } catch {
            log("drag offer cancel skipped seat=\(seatID) error=\(error)")
        }
    }

    nonisolated private static func readOffer(
        label: String,
        mimeTypes: [MIMEType],
        state: DataTransferSmokeState,
        read: (MIMEType, ByteCount, Duration) async throws -> Data
    ) async throws {
        logFilteredMIMEs(label: label, mimeTypes: mimeTypes)
        guard let mimeType = preferredMIMEType(from: mimeTypes) else {
            log("\(label) has no supported MIME type")
            return
        }

        let data = try await read(mimeType, try ByteCount.kilobytes(64), .seconds(2))
        await state.recordRead(label: label, mimeType: mimeType, byteCount: data.count)
        log("\(label) read \(data.count) bytes as \(mimeType) payload=redacted")
    }

    nonisolated private static func transferPayloads(
        label: String,
        serial: InputSerial
    ) -> [DataTransferSourcePayload] {
        let text = "WaylandClientKit data-transfer smoke \(label) \(serial)\n"
        let data = Data(text.utf8)
        return [
            DataTransferSourcePayload(mimeType: .plainTextUTF8, data: data),
            DataTransferSourcePayload(mimeType: .plainText, data: data),
        ]
    }

    nonisolated private static func preferredMIMEType(
        from mimeTypes: [MIMEType]
    ) -> MIMEType? {
        for candidate in [MIMEType.plainTextUTF8, .plainText, .uriList]
        where mimeTypes.contains(candidate) {
            return candidate
        }
        return nil
    }

    nonisolated private static func logFilteredMIMEs(label: String, mimeTypes: [MIMEType]) {
        for mimeType in mimeTypes where !isSupportedMIMEType(mimeType) {
            if isPrivateMIMEType(mimeType) {
                log("\(label) filtered private MIME \(mimeType)")
            } else {
                log("\(label) ignored MIME \(mimeType)")
            }
        }
    }

    nonisolated private static func isSupportedMIMEType(_ mimeType: MIMEType) -> Bool {
        mimeType == .plainTextUTF8 || mimeType == .plainText || mimeType == .uriList
    }

    nonisolated private static func isPrivateMIMEType(_ mimeType: MIMEType) -> Bool {
        let value = mimeType.rawValue
        return value.hasPrefix("application/x-kde-") || value.hasPrefix("application/x-qt-")
    }

    nonisolated private static func showInitialFrame(
        window: Window,
        state: DataTransferSmokeState
    ) async throws {
        let snapshot = await state.snapshot()
        try await window.show { frame in
            draw(frame, snapshot: snapshot)
        }
    }

    nonisolated private static func redrawIfNeeded(
        window: Window,
        state: DataTransferSmokeState
    ) async throws {
        guard try await !window.isClosed else { return }
        guard try await window.needsRedraw else { return }
        let snapshot = await state.snapshot()
        try await window.redraw { frame in
            draw(frame, snapshot: snapshot)
        }
    }

    nonisolated private static func draw(
        _ frame: borrowing SoftwareFrame,
        snapshot: DataTransferSmokeSnapshot
    ) {
        frame.withXRGB8888Rows { row, pixels in
            for index in 0..<pixels.count {
                let red = UInt32((row + snapshot.eventCount * 19) & 0xFF)
                let green = UInt32((index + snapshot.readCount * 31) & 0xFF)
                let blue = UInt32((row + index + snapshot.sourceCount * 43) & 0xFF)
                unsafe pixels[unchecked: index] = (red << 16) | (green << 8) | blue
            }
        }
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

    nonisolated private static func dataTransferDescription(_ event: DataTransferEvent) -> String {
        switch event {
        case .clipboardSelectionChanged(let selection):
            "clipboard seat=\(selection.seatID) offer=\(selection.offer.map(String.init(describing:)) ?? "none")"
        case .primarySelectionChanged(let selection):
            "primary seat=\(selection.seatID) offer=\(selection.offer.map(String.init(describing:)) ?? "none")"
        case .clipboardSourceCancelled(let source):
            "clipboard source cancelled \(source)"
        case .primarySelectionSourceCancelled(let source):
            "primary source cancelled \(source)"
        case .sourceSendRequested(let event):
            "source send requested source=\(event.source) mime=\(event.mimeType)"
        case .sourceWriteSucceeded(let event):
            "source write succeeded source=\(event.source) mime=\(event.mimeType)"
        case .dragSourceCancelled(let source):
            "drag source cancelled \(source)"
        case .dragSourceTargetChanged(let target):
            "drag source target \(target.source) mime=\(target.mimeType.map(String.init(describing:)) ?? "none")"
        case .dragSourceActionChanged(let action):
            "drag source action \(action.source) action=\(action.action)"
        case .dragSourceDropPerformed(let source):
            "drag source drop performed \(source)"
        case .dragSourceFinished(let finished):
            "drag source finished \(finished.source) action=\(finished.finalAction)"
        case .dragEntered(let enter):
            "drag entered seat=\(enter.seatID) offer=\(enter.offer) serial=\(enter.serial)"
        case .dragMotion(let motion):
            "drag motion seat=\(motion.seatID) offer=\(motion.offer) x=\(motion.location.x) y=\(motion.location.y)"
        case .dragLeft(let leave):
            "drag left seat=\(leave.seatID) offer=\(leave.offer)"
        case .dragDropped(let drop):
            "drag dropped seat=\(drop.seatID) offer=\(drop.offer)"
        case .dragOfferChanged(let change):
            "drag offer changed seat=\(change.seatID) offer=\(change.offer)"
        }
    }

    nonisolated private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

private actor DataTransferSmokeState {
    private var current = DataTransferSmokeSnapshot()
    private var activeClipboardSource: ClipboardSource?
    private var activePrimarySelectionSource: PrimarySelectionSource?

    func record(_ event: DataTransferEvent) {
        current.eventCount += 1
        switch event {
        case .clipboardSourceCancelled(let source):
            if activeClipboardSource?.identity == source {
                activeClipboardSource = nil
            }
            current.sourceCount = max(0, current.sourceCount - 1)
        case .primarySelectionSourceCancelled(let source):
            if activePrimarySelectionSource?.identity == source {
                activePrimarySelectionSource = nil
            }
            current.sourceCount = max(0, current.sourceCount - 1)
        case .dragSourceCancelled:
            current.sourceCount = max(0, current.sourceCount - 1)
        default:
            break
        }
    }

    func recordClipboardSource(_ source: ClipboardSource) {
        activeClipboardSource = source
        recordSource("clipboard \(source.identity)")
    }

    func recordPrimarySelectionSource(_ source: PrimarySelectionSource) {
        activePrimarySelectionSource = source
        recordSource("primary \(source.identity)")
    }

    func recordSource(_ label: String) {
        current.sourceCount += 1
        current.lastSource = label
    }

    func recordRead(label: String, mimeType: MIMEType, byteCount: Int) {
        current.readCount += 1
        current.lastRead = "\(label) \(mimeType) \(byteCount) bytes"
    }

    func snapshot() -> DataTransferSmokeSnapshot {
        current
    }

    func summary() -> String {
        "data-transfer summary events=\(current.eventCount) reads=\(current.readCount) "
            + "sources=\(current.sourceCount) lastSource=\(current.lastSource) "
            + "lastRead=\(current.lastRead)"
    }
}

private struct DataTransferSmokeSnapshot: Sendable {
    var eventCount = 0
    var readCount = 0
    var sourceCount = 0
    var lastSource = ""
    var lastRead = ""
}
