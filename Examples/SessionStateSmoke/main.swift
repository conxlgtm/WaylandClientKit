import Foundation
import WaylandClient
import WaylandExampleSupport

@main
enum SessionStateSmoke {
    nonisolated fileprivate static let defaultAppID = "org.swiftwayland.SessionStateSmoke"
    nonisolated fileprivate static let defaultTitle = "SwiftWayland Session State Smoke"

    static func main() async throws {
        let options = try SessionStateOptions.parse(CommandLine.arguments.dropFirst())
        let stateFile = try options.stateFile()
        let savedState = options.restore ? try loadState(from: stateFile) : nil

        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 64,
                textInputEventCapacity: 8,
                dataTransferEventCapacity: 8,
                presentationEventCapacity: 8
            )
        ) { display in
            log("feature: session-state")
            log("capability: local app-owned state")
            log("state-root: \(stateFile.deletingLastPathComponent().path)")
            log("operation: \(options.restore ? "restore" : "save")")

            let capabilities = try await display.capabilities()
            log("activation: \(availabilityDescription(capabilities.xdgActivation))")

            let window = try await display.createTopLevelWindow(
                configuration: try windowConfiguration(restoring: savedState)
            )

            try await window.show { frame in
                draw(frame, restored: savedState != nil)
            }

            let snapshot = try await window.restorationSnapshot
            let nextState = SavedSessionState(snapshot: snapshot, restored: savedState != nil)
            try save(nextState, to: stateFile)

            log("operation: capture-restoration-snapshot pass")
            log("window: \(snapshot.windowID)")
            log("title: \(snapshot.title ?? "unknown")")
            log("app-id: \(snapshot.appID ?? "unknown")")
            log("geometry: \(snapshot.geometry)")
            log("outputs: \(snapshot.outputs.map(\.description).joined(separator: ","))")
            log("state-file: \(stateFile.path)")

            try await runUntilClosed(
                display: display,
                window: window,
                options: options.runOptions,
                stateFile: stateFile
            )
        }
    }

    nonisolated private static func windowConfiguration(restoring state: SavedSessionState?)
        throws -> WindowConfiguration
    {
        try WindowConfiguration(
            title: state?.title ?? defaultTitle,
            appID: state?.appID ?? defaultAppID,
            initialWidth: state?.logicalWidth ?? 360,
            initialHeight: state?.logicalHeight ?? 220,
            closeRequestPolicy: .requestOnly
        )
    }

    private static func runUntilClosed(
        display: WaylandDisplay,
        window: Window,
        options: ExampleRunOptions,
        stateFile: URL
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await consumeDisplayEvents(display.events, window: window)
            }
            if let autoCloseSeconds = options.autoCloseSeconds {
                group.addTask {
                    try await Task.sleep(for: .seconds(autoCloseSeconds))
                    await window.close()
                }
            }

            _ = try await group.next()
            group.cancelAll()
        }

        if options.printSummary {
            log("summary: remainingWindows=0 stateFile=\(stateFile.path)")
        }
        log("result: pass")
        log("cleanup: pass")
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        window: Window
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == window.id:
                try await window.redraw { frame in
                    draw(frame, restored: true)
                }
            case .windowCloseRequested(let windowID) where windowID == window.id:
                await window.close()
            case .windowClosed(let windowID) where windowID == window.id:
                return
            case .diagnostic(let diagnostic):
                log("diagnostic: \(diagnostic)")
            default:
                break
            }
        }
    }

    nonisolated private static func loadState(from url: URL) throws -> SavedSessionState? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            log("restore-state: missing")
            return nil
        }

        let data = try Data(contentsOf: url)
        let state = try JSONDecoder().decode(SavedSessionState.self, from: data)
        log("restore-state: loaded")
        return state
    }

    nonisolated private static func save(_ state: SavedSessionState, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: .atomic)
        log("operation: write-session-state pass")
    }

    nonisolated private static func availabilityDescription(
        _ availability: ProtocolAvailability
    ) -> String {
        switch availability {
        case .unavailable:
            "unavailable"
        case .available(let version):
            "available(version: \(version))"
        }
    }

    nonisolated private static func draw(
        _ frame: borrowing SoftwareFrame,
        restored: Bool
    ) {
        frame.withXRGB8888Rows { row, pixels in
            for x in 0..<Int(frame.width) {
                let stripe = UInt32((x + row) % 96)
                let base: UInt32 = restored ? 0x0030_5030 : 0x0030_3050
                unsafe pixels[unchecked: x] = base | (stripe << 8)
            }
        }
    }

    nonisolated private static func log(_ message: String) {
        print("[SessionStateSmoke] \(message)")
    }
}

private struct SessionStateOptions: Equatable, Sendable {
    let runOptions: ExampleRunOptions
    let restore: Bool
    let stateRoot: String?

    static func parse(_ arguments: ArraySlice<String>) throws -> SessionStateOptions {
        var restore = false
        var stateRoot: String?
        var exampleArguments: [String] = []
        var index = arguments.startIndex

        while index < arguments.endIndex {
            let argument = arguments[index]
            switch argument {
            case "--restore":
                restore = true
            case "--state-root":
                let valueIndex = arguments.index(after: index)
                guard valueIndex < arguments.endIndex else {
                    throw ExampleRunOptionError.missingValue(argument)
                }
                stateRoot = arguments[valueIndex]
                index = valueIndex
            default:
                exampleArguments.append(argument)
            }

            arguments.formIndex(after: &index)
        }

        return SessionStateOptions(
            runOptions: try ExampleRunOptions.parse(exampleArguments[...]),
            restore: restore,
            stateRoot: stateRoot
        )
    }

    func stateFile() throws -> URL {
        let root = try stateRootURL()
        return
            root
            .appendingPathComponent(SessionStateSmoke.defaultAppID, isDirectory: true)
            .appendingPathComponent("session.json")
    }

    private func stateRootURL() throws -> URL {
        if let stateRoot, !stateRoot.isEmpty {
            return URL(fileURLWithPath: stateRoot)
        }

        let environment = ProcessInfo.processInfo.environment
        if let xdgStateHome = environment["XDG_STATE_HOME"], !xdgStateHome.isEmpty {
            return URL(fileURLWithPath: xdgStateHome)
        }

        guard let home = environment["HOME"], !home.isEmpty else {
            throw SessionStateSmokeError.missingStateRoot
        }

        return URL(fileURLWithPath: home)
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("state", isDirectory: true)
    }
}

private struct SavedSessionState: nonisolated Codable, Equatable, Sendable {
    let title: String
    let appID: String
    let logicalWidth: Int32
    let logicalHeight: Int32
    let scaleNumerator: UInt32
    let scaleDenominator: UInt32
    let outputs: [String]
    let restored: Bool

    nonisolated init(snapshot: WindowRestorationSnapshot, restored wasRestored: Bool) {
        title = snapshot.title ?? SessionStateSmoke.defaultTitle
        appID = snapshot.appID ?? SessionStateSmoke.defaultAppID
        logicalWidth = snapshot.geometry.logicalSize.width.rawValue
        logicalHeight = snapshot.geometry.logicalSize.height.rawValue
        scaleNumerator = snapshot.geometry.scale.numerator
        scaleDenominator = snapshot.geometry.scale.denominator
        outputs = snapshot.outputs.map(\.description)
        restored = wasRestored
    }
}

private enum SessionStateSmokeError: Error, CustomStringConvertible {
    case missingStateRoot

    var description: String {
        switch self {
        case .missingStateRoot:
            "XDG_STATE_HOME and HOME are unset. Pass --state-root."
        }
    }
}
