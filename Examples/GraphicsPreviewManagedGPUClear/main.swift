import Foundation
import Glibc
import WaylandClient
import WaylandExampleSupport
import WaylandGraphicsPreview

@main
enum GraphicsPreviewManagedGPUClear {
    nonisolated private static let leftButton = PointerButtonCode(rawValue: 0x110)
    nonisolated private static let resizeHandleBand = 36.0

    static func main() async {
        let result: ManagedGPUClearReport
        let exitCode: Int32
        do {
            let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())
            result = try await run(options: options)
            exitCode = EXIT_SUCCESS
        } catch {
            result = ManagedGPUClearReport(failure: "\(error)")
            exitCode = EXIT_FAILURE
        }

        ManagedGPUClearReportFormatter(report: result).write()
        guard exitCode == EXIT_SUCCESS else {
            exit(exitCode)
        }
    }

    private static func run(options: ExampleRunOptions) async throws -> ManagedGPUClearReport {
        try await WaylandDisplay.withConnection(
            eventStreamConfiguration: try EventStreamConfiguration(
                displayEventCapacity: 64,
                inputEventCapacity: 16,
                textInputEventCapacity: 16,
                dataTransferEventCapacity: 16,
                presentationEventCapacity: 64
            )
        ) { display in
            try await managedClearReport(on: display, options: options)
        }
    }

    nonisolated private static func managedClearReport(
        on display: WaylandDisplay,
        options: ExampleRunOptions
    ) async throws -> ManagedGPUClearReport {
        let capabilities = try await display.graphicsSurfaceCapabilities()
        let backing = try await display.createGraphicsWindowBacking(
            windowConfiguration: WindowConfiguration(
                title: "SwiftWayland Managed GPU Clear",
                appID: "swift-wayland-managed-gpu-clear",
                initialWidth: 360,
                initialHeight: 240,
                bufferCount: 2
            ),
            graphicsConfiguration: WaylandGraphicsConfiguration(
                backingPreference: .managedGPU,
                presentationFeedbackPolicy: .requestWhenAvailable
            )
        )
        let state = ManagedGPUClearRunState()

        log(
            "instructions: drag from inside the content edge/corner to resize, "
                + "then close the window"
        )
        _ = try await submitClearFrame(backing: backing, state: state)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await consumeDisplayEvents(display.events, backing: backing, state: state)
            }
            group.addTask {
                try await consumeInputEvents(
                    display.inputEvents,
                    display: display,
                    backing: backing,
                    state: state
                )
            }
            if let seconds = options.autoCloseSeconds {
                group.addTask {
                    try await Task.sleep(for: .seconds(seconds))
                    try await backing.close()
                }
            }

            _ = try await group.next()
            group.cancelAll()
        }

        if options.printSummary {
            log(await state.summary())
        }

        return await state.report(capabilities: capabilities)
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        backing: WaylandGraphicsWindowBacking,
        state: ManagedGPUClearRunState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == backing.id:
                _ = try await submitClearFrame(backing: backing, state: state)
            case .windowCloseRequested(let windowID) where windowID == backing.id:
                try await backing.close()
                return
            case .windowClosed(let windowID) where windowID == backing.id:
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
        backing: WaylandGraphicsWindowBacking,
        state: ManagedGPUClearRunState
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            guard event.windowID == backing.id else { continue }

            switch event.kind {
            case .pointer(.entered(let location, _)), .pointer(.moved(let location, _)):
                let geometry = try await backing.window.geometry
                let edge = resizeEdge(at: location, in: geometry)
                let cursor = cursor(for: edge)
                let changed = await state.recordPointer(location, edge: edge)
                do {
                    let results = try await display.setPointerCursor(cursor)
                    if changed {
                        log(
                            "resize handle edge=\(edgeDescription(edge)) "
                                + "cursor=\(cursorDescription(cursor)) "
                                + "geometry=\(geometryDescription(geometry)) "
                                + "location=\(location.x),\(location.y) "
                                + "results=\(cursorResultsDescription(results))"
                        )
                    }
                } catch {
                    log(
                        "resize handle cursor failed edge=\(edgeDescription(edge)) "
                            + "cursor=\(cursorDescription(cursor)) error=\(error)"
                    )
                }
            case .pointer(.left):
                _ = await state.recordPointer(nil, edge: nil)
                do {
                    let results = try await display.setPointerCursor(.defaultArrow)
                    log(
                        "resize handle edge=none cursor=left_ptr "
                            + "results=\(cursorResultsDescription(results))"
                    )
                } catch {
                    log("resize handle cursor failed edge=none cursor=left_ptr error=\(error)")
                }
            case .pointer(.button(let button)) where button.state == .pressed:
                guard let location = await state.pointerLocation else { continue }
                let geometry = try await backing.window.geometry
                guard let edge = resizeEdge(at: location, in: geometry) else { continue }
                guard button.button == leftButton else {
                    log(
                        "resize request ignored button=\(button.button) expected=left "
                            + "edge=\(edgeDescription(edge)) "
                            + "geometry=\(geometryDescription(geometry)) "
                            + "location=\(location.x),\(location.y)"
                    )
                    continue
                }
                await state.recordResizeRequest()
                log(
                    "resize request seat=\(event.seatID) serial=\(button.serial) "
                        + "edge=\(edgeDescription(edge)) "
                        + "geometry=\(geometryDescription(geometry)) "
                        + "location=\(location.x),\(location.y)"
                )
                do {
                    try await backing.window.requestInteractiveResize(
                        seatID: event.seatID,
                        serial: button.serial,
                        edge: edge
                    )
                    log("resize request result threw=false")
                } catch {
                    log("resize request result threw=true error=\(error)")
                }
            default:
                break
            }
        }
    }

    nonisolated private static func submitClearFrame(
        backing: WaylandGraphicsWindowBacking,
        state: ManagedGPUClearRunState
    ) async throws -> WaylandGraphicsFrameResult {
        let lease = try await backing.nextFrame()
        let result = try await lease.submit(
            .clearColor(
                WaylandGraphicsClearFrame(
                    color: WaylandGraphicsXRGBColor(red: 0x18, green: 0xB8, blue: 0x92)
                )
            )
        )
        if await state.record(result) {
            log(
                "gpu frame operation=\(result.operation) "
                    + "size=\(result.size.width)x\(result.size.height) "
                    + "backing=\(actualBacking(result.runtimePath))"
            )
        }
        return result
    }

    nonisolated private static func resizeEdge(
        at location: PointerLocation,
        in geometry: SurfaceGeometry
    ) -> WindowResizeEdge? {
        let width = Double(geometry.logicalSize.width.rawValue)
        let height = Double(geometry.logicalSize.height.rawValue)
        let top = location.y <= resizeHandleBand
        let bottom = location.y >= height - resizeHandleBand
        let left = location.x <= resizeHandleBand
        let right = location.x >= width - resizeHandleBand

        switch (top, bottom, left, right) {
        case (true, _, true, _):
            return .topLeft
        case (true, _, _, true):
            return .topRight
        case (_, true, true, _):
            return .bottomLeft
        case (_, true, _, true):
            return .bottomRight
        case (true, _, _, _):
            return .top
        case (_, true, _, _):
            return .bottom
        case (_, _, true, _):
            return .left
        case (_, _, _, true):
            return .right
        default:
            return nil
        }
    }

    nonisolated private static func cursor(for edge: WindowResizeEdge?) -> PointerCursor {
        guard let edge else { return .defaultArrow }
        switch edge {
        case .left, .right:
            return .resizeLeftRight
        case .top, .bottom:
            return .resizeUpDown
        case .topLeft:
            return (try? PointerCursor(name: "nw-resize")) ?? .crosshair
        case .topRight:
            return (try? PointerCursor(name: "ne-resize")) ?? .crosshair
        case .bottomLeft:
            return (try? PointerCursor(name: "sw-resize")) ?? .crosshair
        case .bottomRight:
            return (try? PointerCursor(name: "se-resize")) ?? .crosshair
        }
    }

    nonisolated private static func edgeDescription(_ edge: WindowResizeEdge?) -> String {
        guard let edge else { return "none" }
        switch edge {
        case .top:
            return "top"
        case .bottom:
            return "bottom"
        case .left:
            return "left"
        case .right:
            return "right"
        case .topLeft:
            return "topLeft"
        case .topRight:
            return "topRight"
        case .bottomLeft:
            return "bottomLeft"
        case .bottomRight:
            return "bottomRight"
        }
    }

    nonisolated private static func cursorDescription(_ cursor: PointerCursor) -> String {
        cursor.name ?? "hidden"
    }

    nonisolated private static func cursorResultsDescription(
        _ results: [CursorRequestResult]
    ) -> String {
        if results.isEmpty { return "none" }
        return results.map(cursorResultDescription).joined(separator: ",")
    }

    nonisolated private static func cursorResultDescription(
        _ result: CursorRequestResult
    ) -> String {
        switch result {
        case .set(let seatID, let serial, let cursor):
            return "set(seat=\(seatID),serial=\(serial),cursor=\(cursorDescription(cursor)))"
        case .hidden(let seatID, let serial):
            return "hidden(seat=\(seatID),serial=\(serial))"
        case .skippedNoPointerFocus(let seatID):
            return "skippedNoPointerFocus(seat=\(seatID))"
        }
    }

    nonisolated private static func geometryDescription(_ geometry: SurfaceGeometry) -> String {
        let size = geometry.logicalSize
        return "\(size.width.rawValue)x\(size.height.rawValue)"
    }

    nonisolated private static func actualBacking(
        _ path: WaylandGraphicsRuntimePath
    ) -> String {
        switch path.backing {
        case .active:
            "managedGPU"
        case .configured:
            "managedGPU configured"
        case .fallback(let reason):
            "software fallback(\(reason))"
        case .failed(let reason):
            "failed(\(reason))"
        case .advertised:
            "managedGPU advertised"
        case .pending:
            "pending"
        case .unavailable:
            "unavailable"
        }
    }

    nonisolated private static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

private struct ManagedGPUClearReport: Sendable {
    var capabilities: WaylandGraphicsSurfaceCapabilities?
    var frameResults: [WaylandGraphicsFrameResult]
    var resizeRequestCount: Int
    var failure: String?

    nonisolated init(
        capabilities reportedCapabilities: WaylandGraphicsSurfaceCapabilities? = nil,
        frameResults reportedFrameResults: [WaylandGraphicsFrameResult] = [],
        resizeRequestCount reportedResizeRequestCount: Int = 0,
        failure reportedFailure: String? = nil
    ) {
        capabilities = reportedCapabilities
        frameResults = reportedFrameResults
        resizeRequestCount = reportedResizeRequestCount
        failure = reportedFailure
    }

    var frameResult: WaylandGraphicsFrameResult? {
        frameResults.last
    }
}

private actor ManagedGPUClearRunState {
    private var frameResults: [WaylandGraphicsFrameResult] = []
    private var resizeRequests = 0
    private(set) var pointerLocation: PointerLocation?
    private var pointerEdge: WindowResizeEdge?

    func record(_ result: WaylandGraphicsFrameResult) -> Bool {
        let previousSizes = orderedFrameSizes(frameResults)
        frameResults.append(result)
        let size = "\(result.size.width)x\(result.size.height)"
        return frameResults.count == 1 || !previousSizes.contains(size)
    }

    func recordPointer(_ location: PointerLocation?, edge: WindowResizeEdge?) -> Bool {
        defer {
            pointerLocation = location
            pointerEdge = edge
        }
        return pointerEdge != edge
    }

    func recordResizeRequest() {
        resizeRequests += 1
    }

    func report(capabilities: WaylandGraphicsSurfaceCapabilities) -> ManagedGPUClearReport {
        ManagedGPUClearReport(
            capabilities: capabilities,
            frameResults: frameResults,
            resizeRequestCount: resizeRequests
        )
    }

    func summary() -> String {
        "managed-gpu-clear summary frames=\(frameResults.count) "
            + "resized=\(resizeObserved(frameResults)) "
            + "resizeRequests=\(resizeRequests) "
            + "sizes=\(frameSizesDescription(frameResults))"
    }
}

private struct ManagedGPUClearReportFormatter {
    let report: ManagedGPUClearReport

    func write() {
        let output = lines().joined(separator: "\n") + "\n"
        FileHandle.standardOutput.write(Data(output.utf8))
    }

    private func lines() -> [String] {
        guard let capabilities = report.capabilities,
            let frameResult = report.frameResult
        else {
            return [
                "SwiftWayland Managed GPU Clear",
                "feature: managed-gpu-clear",
                "capability: runtime path unavailable",
                "operation: clear-frame failed",
                "result: failed",
                "cleanup: not observed",
                "notes: no runtime path was produced",
                "display: \(displayName())",
                "compositor: \(compositorName())",
                "failure: \(report.failure ?? "none")",
            ]
        }
        let runtimePath = frameResult.runtimePath

        return [
            "SwiftWayland Managed GPU Clear",
            "feature: managed-gpu-clear",
            "capability: dmabuf \(availability(capabilities.dmabuf))",
            "operation: clear-frame \(frameResult.operation)",
            "result: \(actualBacking(runtimePath))",
            "cleanup: \(report.failure == nil ? "pass" : "not observed")",
            "notes: active GPU requires actual backing managedGPU",
            "display: \(displayName())",
            "compositor: \(compositorName())",
            "dmabuf: \(availability(capabilities.dmabuf))",
            "surface feedback: \(surfaceFeedbackStatus(runtimePath.surfaceFeedback))",
            "render node: \(status(runtimePath.renderNode))",
            "gbm: \(status(runtimePath.gbm))",
            "egl: \(status(runtimePath.egl))",
            "dmabuf import: \(status(runtimePath.dmabufImport))",
            "buffer lifecycle: \(status(runtimePath.bufferLifecycle))",
            "explicit sync: \(availability(capabilities.explicitSync)), runtime \(status(runtimePath.explicitSync))",
            "fifo: \(status(runtimePath.pacing.fifo))",
            "commit timing: \(status(runtimePath.pacing.commitTiming))",
            "metadata content type: \(status(runtimePath.metadata.contentType))",
            "metadata alpha modifier: \(status(runtimePath.metadata.alphaModifier))",
            "metadata tearing control: \(status(runtimePath.metadata.tearingControl))",
            "metadata color representation: \(status(runtimePath.metadata.colorRepresentation))",
            "metadata color management: \(status(runtimePath.metadata.colorManagement))",
            "presentation feedback: \(availability(capabilities.presentationFeedback)), runtime \(status(runtimePath.presentationFeedback))",
            "requested backing: managedGPU",
            "actual backing: \(actualBacking(runtimePath))",
            "runtime dmabuf: \(status(runtimePath.dmabuf))",
            "frame operation: \(frameResult.operation)",
            "frame size: \(frameResult.size.width)x\(frameResult.size.height)",
            "frames submitted: \(report.frameResults.count)",
            "frame sizes: \(frameSizesDescription(report.frameResults))",
            "resize requests: \(report.resizeRequestCount)",
            "resize observed: \(resizeObserved(report.frameResults))",
            "submitted frame result: \(status(frameResult.backing))",
            "release/reuse: \(releaseReuseStatus(runtimePath))",
            "presentation feedback requested: \(frameResult.presentationFeedbackRequested)",
            "fallback reason: \(runtimePath.fallback.map(String.init(describing:)) ?? "none")",
            "failure: \(report.failure ?? "none")",
        ]
    }

    private func displayName() -> String {
        ProcessInfo.processInfo.environment["WAYLAND_DISPLAY"] ?? "unset"
    }

    private func compositorName() -> String {
        let environment = ProcessInfo.processInfo.environment
        let desktop = environment["XDG_CURRENT_DESKTOP"]
        let session = environment["DESKTOP_SESSION"]

        switch (desktop, session) {
        case (.some(let desktopName), .some(let sessionName)):
            return "\(desktopName) / \(sessionName)"
        case (.some(let desktopName), .none):
            return desktopName
        case (.none, .some(let sessionName)):
            return sessionName
        case (.none, .none):
            return "unknown"
        }
    }

    private func availability(
        _ availability: WaylandGraphicsProtocolAvailability
    ) -> String {
        switch availability {
        case .unavailable:
            "unavailable"
        case .pending(let version):
            "pending v\(version)"
        case .available(let version):
            "advertised v\(version)"
        }
    }

    private func status(_ status: WaylandGraphicsRuntimeStatus) -> String {
        switch status {
        case .unavailable:
            "unavailable"
        case .pending:
            "pending"
        case .advertised:
            "advertised"
        case .configured:
            "configured"
        case .active:
            "active"
        case .failed(let reason):
            "failed(\(reason))"
        case .fallback(let reason):
            "fallback(\(reason))"
        }
    }

    private func surfaceFeedbackStatus(_ status: WaylandGraphicsRuntimeStatus) -> String {
        switch status {
        case .configured, .active:
            "usable"
        case .advertised:
            "advertised, not configured"
        case .fallback(let reason):
            "fallback(\(reason))"
        case .failed(let reason):
            "failed(\(reason))"
        case .pending:
            "pending"
        case .unavailable:
            "unavailable"
        }
    }

    private func actualBacking(_ path: WaylandGraphicsRuntimePath) -> String {
        switch path.backing {
        case .active:
            "managedGPU"
        case .configured:
            "managedGPU configured"
        case .fallback(let reason):
            "software fallback(\(reason))"
        case .failed(let reason):
            "failed(\(reason))"
        case .advertised:
            "managedGPU advertised"
        case .pending:
            "pending"
        case .unavailable:
            "unavailable"
        }
    }

    private func releaseReuseStatus(_ path: WaylandGraphicsRuntimePath) -> String {
        switch path.bufferLifecycle {
        case .active, .configured:
            "managed by GPU buffer lifecycle"
        case .fallback:
            "not observed, software fallback"
        case .failed(let reason):
            "not observed, failed(\(reason))"
        case .advertised:
            "not observed"
        case .pending:
            "pending"
        case .unavailable:
            "unavailable"
        }
    }
}

nonisolated private func frameSizesDescription(
    _ results: [WaylandGraphicsFrameResult]
) -> String {
    let sizes = orderedFrameSizes(results)
    return sizes.isEmpty ? "none" : sizes.joined(separator: ",")
}

nonisolated private func resizeObserved(_ results: [WaylandGraphicsFrameResult]) -> Bool {
    orderedFrameSizes(results).count > 1
}

nonisolated private func orderedFrameSizes(
    _ results: [WaylandGraphicsFrameResult]
) -> [String] {
    var seen = Set<String>()
    var sizes: [String] = []
    for result in results {
        let size = "\(result.size.width)x\(result.size.height)"
        if seen.insert(size).inserted {
            sizes.append(size)
        }
    }
    return sizes
}
