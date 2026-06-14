import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum TextInputSmoke {
    static func main() async throws {
        let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())

        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 128,
                textInputEventCapacity: 128,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 16
            )
        ) { display in
            let capabilities = try await display.capabilities()
            log("feature: text-input")
            log("capability: \(availabilityDescription(capabilities.textInput))")
            log("text-input capability \(availabilityDescription(capabilities.textInput))")
            log("text-input lifecycle disable finalizes; do not commit after disable")

            let window = try await display.createTopLevelWindow(
                configuration: try WindowConfiguration(
                    title: "WaylandClientKit Text Input Smoke",
                    appID: "wayland-client-kit-text-input-smoke",
                    initialWidth: 360,
                    initialHeight: 200,
                    closeRequestPolicy: .requestOnly
                )
            )
            let state = TextInputSmokeState()
            try await showInitialFrame(window: window, state: state)

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await consumeDisplayEvents(
                        display.events,
                        window: window,
                        state: state
                    )
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
                    try await consumeTextInputEvents(
                        display.textInputEvents,
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
                        await disableAllSessions(state: state)
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
        state: TextInputSmokeState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == window.id:
                try await redrawIfNeeded(window: window, state: state)
            case .windowCloseRequested(let windowID) where windowID == window.id:
                await disableAllSessions(state: state)
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
        state: TextInputSmokeState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard event.windowID == window.id else { continue }

            switch event.kind {
            case .pointer(.button(let button)) where button.state == .pressed:
                await enableTextInput(
                    display: display,
                    window: window,
                    seatID: event.seatID,
                    state: state
                )
            case .keyboard(.raw(.entered)):
                await enableTextInput(
                    display: display,
                    window: window,
                    seatID: event.seatID,
                    state: state
                )
            case .keyboard(.raw(.left)):
                await disableTextInput(seatID: event.seatID, state: state)
            case .keyboard(.interpreted(.key(let key))):
                guard key.state == .pressed || key.state == .repeated else { continue }
                if let text = key.text.committedString ?? key.utf8 {
                    await state.appendKeyboardFallback(text)
                    log("keyboard fallback seat=\(event.seatID) text=\(text)")
                    await refreshActiveTextInputSessions(state: state)
                    try await window.requestRedraw()
                }
            case .seat(.removed):
                await disableTextInput(seatID: event.seatID, state: state)
            default:
                break
            }
        }
    }

    nonisolated private static func consumeTextInputEvents(
        _ events: TextInputEvents,
        window: Window,
        state: TextInputSmokeState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            await state.recordTextInput(event)
            log("text-input event \(textInputDescription(event))")
            try await window.requestRedraw()
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

    nonisolated private static func enableTextInput(
        display: WaylandDisplay,
        window: Window,
        seatID: SeatID,
        state: TextInputSmokeState
    ) async {
        guard await state.session(for: seatID) == nil else { return }

        do {
            let session = try await display.textInputSession(for: seatID)
            let surroundingText = try await state.surroundingText()
            try await session.enable(for: window)
            try await session.setContentType(
                hints: [.completion, .spellcheck, .preeditShown],
                purpose: .normal
            )
            try await session.setSurroundingText(surroundingText)
            try await session.setCursorRectangle(try textCursorRectangle())
            try await session.commit()
            await showInputPanelIfAvailable(session)
            await state.activate(session)
            log("operation: enable-text-input pass")
            log("text-input enabled seat=\(seatID)")
        } catch {
            log("operation: enable-text-input failed")
            log("text-input enable failed seat=\(seatID) error=\(error)")
        }
    }

    nonisolated private static func disableTextInput(
        seatID: SeatID,
        state: TextInputSmokeState
    ) async {
        guard let session = await state.removeSession(for: seatID) else { return }
        do {
            await hideInputPanelIfAvailable(session)
            try await session.disable()
            log("operation: disable-text-input pass")
            log("text-input disabled seat=\(seatID)")
        } catch {
            log("operation: disable-text-input failed")
            log("text-input disable failed seat=\(seatID) error=\(error)")
        }
    }

    nonisolated private static func disableAllSessions(state: TextInputSmokeState) async {
        for session in await state.removeAllSessions() {
            do {
                await hideInputPanelIfAvailable(session)
                try await session.disable()
                log("operation: disable-text-input pass")
                log("text-input disabled seat=\(session.seatID)")
            } catch {
                log("operation: disable-text-input failed")
                log("text-input disable failed seat=\(session.seatID) error=\(error)")
            }
        }
    }

    nonisolated private static func showInputPanelIfAvailable(
        _ session: TextInputSession
    ) async {
        do {
            try await session.showInputPanel()
            log("operation: show-input-panel pass")
        } catch {
            if isUnsupportedTextInputVersion(error) {
                log("operation: show-input-panel skip(unsupported-version)")
                return
            }
            log("operation: show-input-panel failed")
            log("text-input show input panel failed seat=\(session.seatID) error=\(error)")
        }
    }

    nonisolated private static func hideInputPanelIfAvailable(
        _ session: TextInputSession
    ) async {
        do {
            try await session.hideInputPanel()
            log("operation: hide-input-panel pass")
        } catch {
            if isUnsupportedTextInputVersion(error) {
                log("operation: hide-input-panel skip(unsupported-version)")
                return
            }
            log("operation: hide-input-panel failed")
            log("text-input hide input panel failed seat=\(session.seatID) error=\(error)")
        }
    }

    nonisolated private static func isUnsupportedTextInputVersion(_ error: any Error) -> Bool {
        guard let textInputError = error as? TextInputError else {
            return false
        }

        if case .unsupportedVersion = textInputError {
            return true
        }

        return false
    }

    nonisolated private static func refreshActiveTextInputSessions(
        state: TextInputSmokeState
    ) async {
        let surroundingText: TextInputSurroundingText
        do {
            surroundingText = try await state.surroundingText()
        } catch {
            log("text-input surrounding text failed error=\(error)")
            return
        }

        for session in await state.activeSessions() {
            do {
                try await session.setTextChangeCause(.other)
                try await session.setSurroundingText(surroundingText)
                try await session.setCursorRectangle(try textCursorRectangle())
                try await session.commit()
            } catch {
                log("text-input refresh failed seat=\(session.seatID) error=\(error)")
            }
        }
    }

    nonisolated private static func showInitialFrame(
        window: Window,
        state: TextInputSmokeState
    ) async throws {
        let snapshot = await state.snapshot()
        try await window.show { frame in
            draw(frame, snapshot: snapshot)
        }
    }

    nonisolated private static func redrawIfNeeded(
        window: Window,
        state: TextInputSmokeState
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
        snapshot: TextInputSmokeSnapshot
    ) {
        let inputCount = UInt32(snapshot.textInputText.utf8.count)
        let fallbackCount = UInt32(snapshot.keyboardFallbackText.utf8.count)
        let preeditCount = UInt32(snapshot.preeditText.utf8.count)
        frame.withXRGB8888Rows { row, pixels in
            for index in 0..<pixels.count {
                let red = UInt32((row * 3 + Int(inputCount) * 19) & 0xFF)
                let green = UInt32((index + Int(fallbackCount) * 23) & 0xFF)
                let blue = UInt32((row + index + Int(preeditCount) * 29) & 0xFF)
                unsafe pixels[unchecked: index] = (red << 16) | (green << 8) | blue
            }
        }
    }

    nonisolated private static func textCursorRectangle() throws -> LogicalRect {
        try LogicalRect(x: 24, y: 64, width: 2, height: 24)
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

    nonisolated private static func textInputDescription(_ event: TextInputEvent) -> String {
        switch event {
        case .entered(let focus):
            "entered seat=\(focus.seatID) target=\(focus.target)"
        case .left(let focus):
            "left seat=\(focus.seatID) target=\(focus.target)"
        case .preedit(let preedit):
            "preedit seat=\(preedit.seatID) text=\(preedit.text)"
        case .committed(let commit):
            "committed seat=\(commit.seatID) text=\(commit.text)"
        case .deleteSurroundingText(let delete):
            "delete seat=\(delete.seatID) before=\(delete.beforeLength) after=\(delete.afterLength)"
        case .action(let action):
            "action seat=\(action.seatID) action=\(action.action.rawValue) serial=\(action.serial)"
        case .language(let language):
            "language seat=\(language.seatID) value=\(languageDescription(language.language))"
        case .done(let done):
            "done seat=\(done.seatID) serial=\(done.serial)"
        case .diagnostic(let diagnostic):
            "diagnostic seat=\(diagnostic.seatID.map(String.init(describing:)) ?? "none") "
                + "operation=\(diagnostic.operation) message=\(diagnostic.message)"
        }
    }

    nonisolated private static func languageDescription(_ language: TextInputLanguage) -> String {
        switch language {
        case .unknown:
            "unknown"
        case .tag(let tag):
            tag
        }
    }

    nonisolated private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

private actor TextInputSmokeState {
    private var current = TextInputSmokeSnapshot()
    private var sessionsBySeatID: [SeatID: TextInputSession] = [:]

    func session(for seatID: SeatID) -> TextInputSession? {
        sessionsBySeatID[seatID]
    }

    func activate(_ session: TextInputSession) {
        sessionsBySeatID[session.seatID] = session
        current.activeSeatCount = sessionsBySeatID.count
    }

    func removeSession(for seatID: SeatID) -> TextInputSession? {
        let session = sessionsBySeatID.removeValue(forKey: seatID)
        current.activeSeatCount = sessionsBySeatID.count
        return session
    }

    func removeAllSessions() -> [TextInputSession] {
        let sessions = Array(sessionsBySeatID.values)
        sessionsBySeatID.removeAll()
        current.activeSeatCount = 0
        return sessions
    }

    func activeSessions() -> [TextInputSession] {
        Array(sessionsBySeatID.values)
    }

    func surroundingText() throws -> TextInputSurroundingText {
        let text = current.textInputText + current.keyboardFallbackText
        return try TextInputSurroundingText.insertionPoint(text, cursor: text.endIndex)
    }

    func appendKeyboardFallback(_ text: String) {
        current.keyboardFallbackText += text
        current.sequence += 1
    }

    func recordTextInput(_ event: TextInputEvent) {
        current.sequence += 1
        switch event {
        case .preedit(let preedit):
            current.preeditText = preedit.text
        case .committed(let commit):
            current.textInputText += commit.text
            current.preeditText = ""
            current.commitCount += 1
        case .deleteSurroundingText:
            current.preeditText = ""
        case .entered, .left, .action, .language, .done, .diagnostic:
            break
        }
    }

    func snapshot() -> TextInputSmokeSnapshot {
        current
    }

    func summary() -> String {
        var fields = [
            "text-input summary activeSeats=\(current.activeSeatCount)",
            "commits=\(current.commitCount)",
            "keyboardFallbackBytes=\(current.keyboardFallbackText.utf8.count)",
            "textInputBytes=\(current.textInputText.utf8.count)",
            "sequence=\(current.sequence)",
        ]
        if current.commitCount == 0 {
            fields.append("no text-input commits observed")
        }
        return fields.joined(separator: " ")
    }
}

private struct TextInputSmokeSnapshot: Sendable {
    var textInputText = ""
    var keyboardFallbackText = ""
    var preeditText = ""
    var activeSeatCount = 0
    var commitCount = 0
    var sequence = 0
}
