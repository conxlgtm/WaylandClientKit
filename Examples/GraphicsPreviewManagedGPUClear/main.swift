import Foundation
import Glibc
import WaylandClient
import WaylandExampleSupport
import WaylandGraphicsPreview

@main
enum GraphicsPreviewManagedGPUClear {
    nonisolated fileprivate static let leftButton = PointerButtonCode(rawValue: 0x110)
    nonisolated fileprivate static let resizeHandleBand = 12.0

    static func main() async {
        let result: ManagedGPUClearReport
        let exitCode: Int32
        do {
            let options = try ExampleRunOptions.parse(CommandLine.arguments.dropFirst())
            result = try await run(options: options)
            exitCode = result.failure == nil ? EXIT_SUCCESS : EXIT_FAILURE
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
            applicationID: "org.waylandclientkit.GraphicsPreviewManagedGPUClear",
            eventStreamConfiguration: try EventStreamConfiguration(
                eventCapacity: 64,
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
        let presentationPolicy = requestedPresentationPolicy()
        let synchronizationPolicy = try requestedSynchronizationPolicy(options.synchronization)
        let pacingPolicy = try requestedPacingPolicy(options.pacing)
        let metadataPolicy = try requestedMetadataPolicy(options.metadata)
        let frameMetadata = try requestedFrameMetadata(options)
        let capabilities = try await display.graphicsSurfaceCapabilities()
        let displayCapabilities = try await display.capabilities()
        let backing = try await display.createGraphicsWindowBacking(
            windowConfiguration: WindowConfiguration(
                title: "WaylandClientKit Managed GPU Clear",
                appID: "wayland-client-kit-managed-gpu-clear",
                initialWidth: 360,
                initialHeight: 240,
                bufferCount: 2,
                decorationPreference: .preferClientSide
            ),
            graphicsConfiguration: WaylandGraphicsConfiguration(
                presentationPolicy: presentationPolicy,
                synchronizationPolicy: synchronizationPolicy,
                pacingPolicy: pacingPolicy,
                metadataPolicy: metadataPolicy,
                presentationFeedbackPolicy: .requestWhenAvailable
            )
        )
        let state = ManagedGPUClearRunState()

        log(
            "instructions: drag from inside the content edge/corner to resize; "
                + "drag from the interior to move; then close the window"
        )
        log(
            "display capability xdgDecoration="
                + "\(displayAvailability(displayCapabilities.xdgDecoration))"
        )
        log("requested presentation policy=\(presentationPolicyDescription(presentationPolicy))")
        log("synchronization policy requested=\(synchronizationDescription(synchronizationPolicy))")
        log("pacing requested=\(pacingDescription(pacingPolicy))")
        log("metadata policy requested=\(metadataPolicyDescription(metadataPolicy))")
        log("content type requested=\(contentTypeDescription(frameMetadata.contentType))")
        log(
            "presentation hint requested="
                + presentationHintDescription(frameMetadata.presentationHint)
        )
        try await backing.window.setMinimumSize(PositiveLogicalSize(width: 1, height: 1))
        try await backing.window.setMaximumSize(nil)
        log("resize constraints minimum=1x1 maximum=unset")
        do {
            _ = try await submitClearFrame(backing: backing, state: state, metadata: frameMetadata)
        } catch {
            let runtimePath = try? await backing.runtimePath
            await backing.close()
            return ManagedGPUClearReport(
                capabilities: capabilities,
                runtimePath: runtimePath,
                requestedPresentationPolicy: presentationPolicy,
                synchronizationPolicy: synchronizationPolicy,
                pacingPolicy: pacingPolicy,
                metadataPolicy: metadataPolicy,
                metadata: frameMetadata,
                failure: "\(error)"
            )
        }
        log("initial window \(await windowSnapshotDescription(backing.window))")
        let inputActionState = ManagedGPUClearInputActionState(windowID: backing.id)
        let inputActionID = try await display.installInputSerialAction { event, context in
            inputActionState.handle(event, context: context)
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await consumeDisplayEvents(
                        display.events,
                        backing: backing,
                        state: state,
                        metadata: frameMetadata
                    )
                }
                if let seconds = options.autoCloseSeconds {
                    group.addTask {
                        try await Task.sleep(for: .seconds(seconds))
                        await backing.close()
                    }
                }

                _ = try await group.next()
                group.cancelAll()
            }
        } catch {
            await display.removeInputSerialAction(inputActionID)
            throw error
        }
        await display.removeInputSerialAction(inputActionID)

        if options.printSummary {
            log(await state.summary(resizeRequestCount: inputActionState.resizeRequestCount))
        }

        return await state.report(
            capabilities: capabilities,
            requestedPresentationPolicy: presentationPolicy,
            synchronizationPolicy: synchronizationPolicy,
            pacingPolicy: pacingPolicy,
            metadataPolicy: metadataPolicy,
            metadata: frameMetadata,
            resizeRequestCount: inputActionState.resizeRequestCount
        )
    }

    nonisolated private static func consumeDisplayEvents(
        _ events: DisplayEvents,
        backing: WaylandGraphicsWindowBacking,
        state: ManagedGPUClearRunState,
        metadata: WaylandGraphicsFrameMetadata
    ) async throws {
        var iterator = events.makeAsyncIterator()
        while !Task.isCancelled, let event = try await iterator.next() {
            switch event {
            case .redrawRequested(let windowID) where windowID == backing.id:
                _ = try await submitClearFrame(
                    backing: backing,
                    state: state,
                    metadata: metadata
                )
            case .windowCloseRequested(let windowID) where windowID == backing.id:
                await backing.close()
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

    nonisolated private static func submitClearFrame(
        backing: WaylandGraphicsWindowBacking,
        state: ManagedGPUClearRunState,
        metadata: WaylandGraphicsFrameMetadata
    ) async throws -> WaylandGraphicsFrameResult {
        let lease = try await backing.nextFrame()
        let result = try await lease.submit(
            .clearColor(
                WaylandGraphicsClearFrame(
                    color: WaylandGraphicsXRGBColor(red: 0x18, green: 0xB8, blue: 0x92),
                    metadata: metadata
                )
            )
        )
        let observation = await state.record(result)
        if observation.shouldLog {
            log(
                "gpu frame \(observation.description) operation=\(result.operation) "
                    + "size=\(result.size.width)x\(result.size.height) "
                    + "backing=\(actualBacking(result.runtimePath))"
            )
        }
        return result
    }

    nonisolated fileprivate static func resizeEdge(
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

    nonisolated fileprivate static func cursor(for edge: WindowResizeEdge?) -> PointerCursor {
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

    nonisolated fileprivate static func edgeDescription(_ edge: WindowResizeEdge?) -> String {
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

    nonisolated fileprivate static func geometryDescription(_ geometry: SurfaceGeometry) -> String {
        let size = geometry.logicalSize
        return "\(size.width.rawValue)x\(size.height.rawValue)"
    }

    nonisolated fileprivate static func snapshotDescription(
        _ snapshot: WindowStateSnapshot,
        effectiveDecorationMode: WindowDecorationMode
    ) -> String {
        "size=\(snapshot.size.width.rawValue)x\(snapshot.size.height.rawValue) "
            + "states=\(snapshot.states) "
            + "capabilities=\(snapshot.managerCapabilities) "
            + "configureDecoration=\(String(describing: snapshot.decorationMode)) "
            + "effectiveDecoration=\(effectiveDecorationMode)"
    }

    nonisolated private static func windowSnapshotDescription(_ window: Window) async -> String {
        do {
            let snapshot = try await window.stateSnapshot
            let effectiveDecorationMode = try await window.decorationMode
            return snapshotDescription(
                snapshot,
                effectiveDecorationMode: effectiveDecorationMode
            )
        } catch {
            return "snapshotError=\(error)"
        }
    }

    nonisolated private static func displayAvailability(
        _ availability: ProtocolAvailability
    ) -> String {
        switch availability {
        case .unavailable:
            "unavailable"
        case .available(let version):
            "available v\(version)"
        }
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

    nonisolated private static func requestedPresentationPolicy()
        -> WaylandGraphicsPresentationPolicy
    {
        switch ProcessInfo.processInfo.environment["WCK_GRAPHICS_PREVIEW_BACKING"]?.lowercased() {
        case "software", "shm":
            .software
        default:
            .managedGPU(fallback: .software)
        }
    }

    nonisolated private static func requestedSynchronizationPolicy(
        _ rawValue: String?
    ) throws -> WaylandGraphicsSynchronizationPolicy {
        switch normalized(rawValue) {
        case nil, "implicit", "implicit-only":
            .implicitOnly
        case "prefer-explicit", "explicit":
            .preferExplicit
        case "require-explicit":
            .requireExplicit
        case .some(let value):
            throw ExampleRunOptionError.unknownArgument("--sync \(value)")
        }
    }

    nonisolated private static func requestedPacingPolicy(
        _ rawValue: String?
    ) throws -> WaylandGraphicsPacingPolicy {
        switch normalized(rawValue) {
        case nil, "none":
            .none
        case "fifo":
            .preferFIFO
        case "commit-timing":
            .preferCommitTiming
        case .some(let value):
            throw ExampleRunOptionError.unknownArgument("--pacing \(value)")
        }
    }

    nonisolated private static func requestedMetadataPolicy(
        _ rawValue: String?
    ) throws -> WaylandGraphicsMetadataPolicy {
        switch normalized(rawValue) {
        case nil, "none":
            .none
        case "prefer", "prefer-available":
            .preferAvailable
        case .some(let value):
            throw ExampleRunOptionError.unknownArgument("--metadata \(value)")
        }
    }

    nonisolated private static func requestedFrameMetadata(
        _ options: ExampleRunOptions
    ) throws -> WaylandGraphicsFrameMetadata {
        try WaylandGraphicsFrameMetadata(
            contentType: requestedContentType(options.contentType),
            presentationHint: requestedPresentationHint(options.presentationHint)
        )
    }

    nonisolated private static func requestedContentType(
        _ rawValue: String?
    ) throws -> WaylandGraphicsContentType? {
        switch normalized(rawValue) {
        case nil:
            nil
        case "none":
            WaylandGraphicsContentType.none
        case "photo":
            .photo
        case "video":
            .video
        case "game":
            .game
        case .some(let value):
            throw ExampleRunOptionError.unknownArgument("--content-type \(value)")
        }
    }

    nonisolated private static func requestedPresentationHint(
        _ rawValue: String?
    ) throws -> WaylandGraphicsPresentationHint? {
        switch normalized(rawValue) {
        case nil:
            nil
        case "vsync":
            .vsync
        case "async":
            .async
        case .some(let value):
            throw ExampleRunOptionError.unknownArgument("--presentation-hint \(value)")
        }
    }

    nonisolated private static func normalized(_ value: String?) -> String? {
        value?.lowercased().replacingOccurrences(of: "_", with: "-")
    }

    nonisolated fileprivate static func presentationPolicyDescription(
        _ policy: WaylandGraphicsPresentationPolicy
    ) -> String {
        switch policy {
        case .managedGPU(fallback: .software):
            "managedGPU(fallback: software)"
        case .managedGPU(fallback: .unavailable):
            "managedGPU(fallback: unavailable)"
        case .externalGPU(fallback: .software):
            "externalGPU(fallback: software)"
        case .externalGPU(fallback: .unavailable):
            "externalGPU(fallback: unavailable)"
        case .software:
            "software"
        }
    }

    nonisolated fileprivate static func synchronizationDescription(
        _ policy: WaylandGraphicsSynchronizationPolicy
    ) -> String {
        switch policy {
        case .implicitOnly:
            "implicitOnly"
        case .preferExplicit:
            "preferExplicit"
        case .requireExplicit:
            "requireExplicit"
        }
    }

    nonisolated fileprivate static func pacingDescription(
        _ policy: WaylandGraphicsPacingPolicy
    ) -> String {
        switch policy {
        case .none:
            "none"
        case .preferFIFO:
            "preferFIFO"
        case .preferCommitTiming:
            "preferCommitTiming"
        }
    }

    nonisolated fileprivate static func metadataPolicyDescription(
        _ policy: WaylandGraphicsMetadataPolicy
    ) -> String {
        switch policy {
        case .none:
            "none"
        case .preferAvailable:
            "preferAvailable"
        }
    }

    nonisolated fileprivate static func contentTypeDescription(
        _ contentType: WaylandGraphicsContentType?
    ) -> String {
        guard let contentType else { return "not requested" }
        switch contentType {
        case .none:
            return "none"
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .game:
            return "game"
        }
    }

    nonisolated fileprivate static func presentationHintDescription(
        _ hint: WaylandGraphicsPresentationHint?
    ) -> String {
        guard let hint else { return "not requested" }
        switch hint {
        case .vsync:
            return "vsync"
        case .async:
            return "async"
        }
    }

    nonisolated fileprivate static func log(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}

nonisolated private final class ManagedGPUClearInputActionState: @unchecked Sendable {
    private let lock = NSLock()
    private let windowID: WindowID
    private var pointerLocation: PointerLocation?
    private var pointerEdge: WindowResizeEdge?
    private var pointerGeometry: SurfaceGeometry?
    private var resizeRequests = 0

    init(windowID managedWindowID: WindowID) {
        windowID = managedWindowID
    }

    var resizeRequestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return resizeRequests
    }

    func handle(_ event: InputEvent, context: InputSerialActionContext) {
        guard event.windowID == windowID else { return }

        switch event.kind {
        case .pointer(.entered(let location, _)),
            .pointer(.moved(let location, _)):
            handlePointerLocation(location, context: context)
        case .pointer(.left):
            handlePointerLeft(context: context)
        case .pointer(.button(let button)) where button.state == .pressed:
            handleButtonPress(button, event: event, context: context)
        default:
            break
        }
    }

    private func handlePointerLocation(
        _ location: PointerLocation,
        context: InputSerialActionContext
    ) {
        do {
            let geometry = try context.windowGeometry(windowID)
            let edge = GraphicsPreviewManagedGPUClear.resizeEdge(at: location, in: geometry)
            let cursor = GraphicsPreviewManagedGPUClear.cursor(for: edge)
            recordPointer(location, edge: edge, geometry: geometry)
            _ = try context.setPointerCursor(cursor)
            try context.requestRedraw(windowID)
        } catch {
            GraphicsPreviewManagedGPUClear.log("resize handle cursor failed \(error)")
        }
    }

    private func handlePointerLeft(context: InputSerialActionContext) {
        recordPointer(nil, edge: nil, geometry: nil)
        do {
            _ = try context.setPointerCursor(.defaultArrow)
            try context.requestRedraw(windowID)
        } catch {
            GraphicsPreviewManagedGPUClear.log("resize handle cursor failed \(error)")
        }
    }

    private func handleButtonPress(
        _ button: PointerButtonEvent,
        event: InputEvent,
        context: InputSerialActionContext
    ) {
        guard let snapshot = pointerSnapshot() else { return }
        let edgeDescription = GraphicsPreviewManagedGPUClear.edgeDescription(snapshot.edge)
        guard button.button == GraphicsPreviewManagedGPUClear.leftButton else {
            return
        }

        if let edge = snapshot.edge {
            handleResizeRequest(
                edge,
                snapshot: snapshot,
                edgeDescription: edgeDescription,
                button: button,
                event: event,
                context: context
            )
        } else {
            handleMoveRequest(
                snapshot: snapshot,
                button: button,
                event: event,
                context: context
            )
        }
    }

    private func handleResizeRequest(
        _ edge: WindowResizeEdge,
        snapshot: (location: PointerLocation, edge: WindowResizeEdge?, geometry: SurfaceGeometry),
        edgeDescription: String,
        button: PointerButtonEvent,
        event: InputEvent,
        context: InputSerialActionContext
    ) {
        let requestDescription =
            "resize request seat=\(event.seatID) "
            + "serial=\(button.serial) "
            + "edge=\(edgeDescription) "
            + "geometry=\(GraphicsPreviewManagedGPUClear.geometryDescription(snapshot.geometry)) "
            + "location=\(snapshot.location.x),\(snapshot.location.y)"
        do {
            try context.requestInteractiveResize(
                windowID,
                seatID: event.seatID,
                serial: button.serial,
                edge: edge
            )
            recordResizeRequest()
            try context.requestRedraw(windowID)
            GraphicsPreviewManagedGPUClear.log(
                "resize request result=pass " + requestDescription
            )
        } catch {
            GraphicsPreviewManagedGPUClear.log(
                "resize request result=fail " + requestDescription + " error=\(error)"
            )
        }
    }

    private func handleMoveRequest(
        snapshot: (location: PointerLocation, edge: WindowResizeEdge?, geometry: SurfaceGeometry),
        button: PointerButtonEvent,
        event: InputEvent,
        context: InputSerialActionContext
    ) {
        let requestDescription =
            "move request seat=\(event.seatID) "
            + "serial=\(button.serial) "
            + "geometry=\(GraphicsPreviewManagedGPUClear.geometryDescription(snapshot.geometry)) "
            + "location=\(snapshot.location.x),\(snapshot.location.y)"
        do {
            try context.requestInteractiveMove(
                windowID,
                seatID: event.seatID,
                serial: button.serial
            )
            GraphicsPreviewManagedGPUClear.log("move request result=pass " + requestDescription)
        } catch {
            GraphicsPreviewManagedGPUClear.log(
                "move request result=fail " + requestDescription + " error=\(error)"
            )
        }
    }

    private func recordPointer(
        _ location: PointerLocation?,
        edge: WindowResizeEdge?,
        geometry: SurfaceGeometry?
    ) {
        lock.lock()
        defer { lock.unlock() }
        pointerLocation = location
        pointerEdge = edge
        pointerGeometry = geometry
    }

    private func pointerSnapshot()
        -> (location: PointerLocation, edge: WindowResizeEdge?, geometry: SurfaceGeometry)?
    {
        lock.lock()
        defer { lock.unlock() }
        guard let pointerLocation, let pointerGeometry else { return nil }
        return (pointerLocation, pointerEdge, pointerGeometry)
    }

    private func recordResizeRequest() {
        lock.lock()
        defer { lock.unlock() }
        resizeRequests += 1
    }
}

private enum ManagedGPUClearFrameObservation: CustomStringConvertible, Sendable {
    case none
    case initial
    case resizeObserved

    nonisolated var shouldLog: Bool {
        switch self {
        case .initial, .resizeObserved:
            true
        case .none:
            false
        }
    }

    nonisolated var description: String {
        switch self {
        case .initial:
            "initial"
        case .resizeObserved:
            "resize-observed"
        case .none:
            "unchanged"
        }
    }
}

private struct ManagedGPUClearReport: Sendable {
    var capabilities: WaylandGraphicsSurfaceCapabilities?
    var runtimePath: WaylandGraphicsRuntimePath?
    var frameResults: [WaylandGraphicsFrameResult]
    var requestedPresentationPolicy: WaylandGraphicsPresentationPolicy
    var synchronizationPolicy: WaylandGraphicsSynchronizationPolicy
    var pacingPolicy: WaylandGraphicsPacingPolicy
    var metadataPolicy: WaylandGraphicsMetadataPolicy
    var metadata: WaylandGraphicsFrameMetadata
    var resizeRequestCount: Int
    var failure: String?

    nonisolated init(
        capabilities reportedCapabilities: WaylandGraphicsSurfaceCapabilities? = nil,
        runtimePath reportedRuntimePath: WaylandGraphicsRuntimePath? = nil,
        frameResults reportedFrameResults: [WaylandGraphicsFrameResult] = [],
        requestedPresentationPolicy reportedPresentationPolicy:
            WaylandGraphicsPresentationPolicy = .managedGPU(fallback: .software),
        synchronizationPolicy reportedSynchronizationPolicy:
            WaylandGraphicsSynchronizationPolicy = .implicitOnly,
        pacingPolicy reportedPacingPolicy: WaylandGraphicsPacingPolicy = .none,
        metadataPolicy reportedMetadataPolicy: WaylandGraphicsMetadataPolicy = .none,
        metadata reportedMetadata: WaylandGraphicsFrameMetadata = .default,
        resizeRequestCount reportedResizeRequestCount: Int = 0,
        failure reportedFailure: String? = nil
    ) {
        capabilities = reportedCapabilities
        runtimePath = reportedRuntimePath
        frameResults = reportedFrameResults
        requestedPresentationPolicy = reportedPresentationPolicy
        synchronizationPolicy = reportedSynchronizationPolicy
        pacingPolicy = reportedPacingPolicy
        metadataPolicy = reportedMetadataPolicy
        metadata = reportedMetadata
        resizeRequestCount = reportedResizeRequestCount
        failure = reportedFailure
    }

    var frameResult: WaylandGraphicsFrameResult? {
        frameResults.last
    }

    var observedRuntimePath: WaylandGraphicsRuntimePath? {
        frameResult?.runtimePath ?? runtimePath
    }
}

private actor ManagedGPUClearRunState {
    private var frameResults: [WaylandGraphicsFrameResult] = []

    func record(_ result: WaylandGraphicsFrameResult) -> ManagedGPUClearFrameObservation {
        let hadResize = resizeObserved(frameResults)
        frameResults.append(result)
        if frameResults.count == 1 {
            return .initial
        }
        if !hadResize, resizeObserved(frameResults) {
            return .resizeObserved
        }
        return .none
    }

    func report(
        capabilities: WaylandGraphicsSurfaceCapabilities,
        requestedPresentationPolicy: WaylandGraphicsPresentationPolicy,
        synchronizationPolicy: WaylandGraphicsSynchronizationPolicy,
        pacingPolicy: WaylandGraphicsPacingPolicy,
        metadataPolicy: WaylandGraphicsMetadataPolicy,
        metadata: WaylandGraphicsFrameMetadata,
        resizeRequestCount: Int
    ) -> ManagedGPUClearReport {
        ManagedGPUClearReport(
            capabilities: capabilities,
            frameResults: frameResults,
            requestedPresentationPolicy: requestedPresentationPolicy,
            synchronizationPolicy: synchronizationPolicy,
            pacingPolicy: pacingPolicy,
            metadataPolicy: metadataPolicy,
            metadata: metadata,
            resizeRequestCount: resizeRequestCount
        )
    }

    func summary(resizeRequestCount: Int) -> String {
        "managed-gpu-clear summary frames=\(frameResults.count) "
            + "resized=\(resizeObserved(frameResults)) "
            + "resizeRequests=\(resizeRequestCount) "
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
            let runtimePath = report.observedRuntimePath
        else {
            return [
                "WaylandClientKit Managed GPU Clear",
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
        let frameResult = report.frameResult
        let frameOperation = frameResult.map { String(describing: $0.operation) } ?? "none"
        let frameSize = frameResult.map { "\($0.size.width)x\($0.size.height)" } ?? "unknown"
        let submittedFrameStatus =
            frameResult.map { status($0.backing) } ?? status(runtimePath.backing)

        return [
            "WaylandClientKit Managed GPU Clear",
            "feature: managed-gpu-clear",
            "capability: dmabuf \(availability(capabilities.dmabuf))",
            "operation: clear-frame \(frameResult.map { String(describing: $0.operation) } ?? "failed")",
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
            "synchronization policy requested: \(GraphicsPreviewManagedGPUClear.synchronizationDescription(report.synchronizationPolicy))",
            "explicit sync: \(availability(capabilities.explicitSync)), runtime \(status(runtimePath.explicitSync))",
            "pacing requested: \(GraphicsPreviewManagedGPUClear.pacingDescription(report.pacingPolicy))",
            "fifo: \(status(runtimePath.pacing.fifo))",
            "commit timing: \(status(runtimePath.pacing.commitTiming))",
            "metadata policy requested: \(GraphicsPreviewManagedGPUClear.metadataPolicyDescription(report.metadataPolicy))",
            "content type requested: \(GraphicsPreviewManagedGPUClear.contentTypeDescription(report.metadata.contentType))",
            "metadata content type: \(status(runtimePath.metadata.contentType))",
            "metadata alpha modifier: \(status(runtimePath.metadata.alphaModifier))",
            "presentation hint requested: \(GraphicsPreviewManagedGPUClear.presentationHintDescription(report.metadata.presentationHint))",
            "metadata tearing control: \(status(runtimePath.metadata.tearingControl))",
            "metadata color representation: \(status(runtimePath.metadata.colorRepresentation))",
            "metadata color management: \(status(runtimePath.metadata.colorManagement))",
            "presentation feedback: \(availability(capabilities.presentationFeedback)), runtime \(status(runtimePath.presentationFeedback))",
            "requested presentation policy: \(GraphicsPreviewManagedGPUClear.presentationPolicyDescription(report.requestedPresentationPolicy))",
            "actual backing: \(actualBacking(runtimePath))",
            "runtime dmabuf: \(status(runtimePath.dmabuf))",
            "frame operation: \(frameOperation)",
            "frame size: \(frameSize)",
            "frames submitted: \(report.frameResults.count)",
            "frame sizes: \(frameSizesDescription(report.frameResults))",
            "resize requests: \(report.resizeRequestCount)",
            "resize observed: \(resizeObserved(report.frameResults))",
            "submitted frame result: \(submittedFrameStatus)",
            "release/reuse: \(releaseReuseStatus(runtimePath))",
            "presentation feedback requested: \(frameResult?.presentationFeedbackRequested ?? false)",
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
    guard !sizes.isEmpty else { return "none" }
    guard sizes.count > 12 else { return sizes.joined(separator: ",") }

    let first = sizes.first ?? "unknown"
    let last = sizes.last ?? "unknown"
    let sample = (Array(sizes.prefix(4)) + Array(sizes.suffix(4))).joined(separator: ",")
    return "\(sizes.count) unique, first=\(first), last=\(last), sample=\(sample)"
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
