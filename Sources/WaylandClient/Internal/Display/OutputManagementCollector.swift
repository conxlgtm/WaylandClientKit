import WaylandRaw

final class OutputManagementCollection {
    let manager: RawWlrOutputManager
    let snapshot: OutputManagementSnapshot
    private let states: [OutputManagementCollector.HeadState]
    private let collector: OutputManagementCollector

    init(
        manager outputManager: RawWlrOutputManager,
        snapshot outputSnapshot: OutputManagementSnapshot,
        states outputStates: [OutputManagementCollector.HeadState],
        collector outputCollector: OutputManagementCollector
    ) {
        manager = outputManager
        snapshot = outputSnapshot
        states = outputStates
        collector = outputCollector
    }

    func configureCurrentState(on configuration: RawWlrOutputConfiguration) throws {
        for state in states where !state.isFinished {
            if state.enabled {
                let configurationHead = try configuration.enable(head: state.rawHead)
                if let mode = state.currentMode?.rawMode {
                    configurationHead.setMode(mode)
                }
                if let position = state.position {
                    configurationHead.setPosition(x: position.x, y: position.y)
                }
                if let transform = state.transform {
                    configurationHead.setTransform(transform.rawValue)
                }
                if let scale = state.scale {
                    configurationHead.setScale(WaylandFixed(scale))
                }
            } else {
                configuration.disable(head: state.rawHead)
            }
        }
    }

    func destroy() {
        manager.destroy()
    }

    func stopAndDrain(connection: RawDisplayConnection, timeoutMilliseconds: Int32) throws {
        manager.stop()
        guard !collector.isFinished else { return }

        try connection.completeInitialDiscovery(timeoutMilliseconds: timeoutMilliseconds)
        guard collector.isFinished else {
            throw ClientError.display(.outputManagementIncomplete)
        }
    }
}

final class OutputManagementCollector {
    final class ModeState {
        let rawMode: RawWlrOutputMode
        var size: PositivePixelSize?
        var refresh: OutputRefreshRate = .unspecified
        var isPreferred = false
        var isFinished = false

        init(rawMode outputMode: RawWlrOutputMode) {
            rawMode = outputMode
        }

        func copy() -> ModeState {
            let copy = ModeState(rawMode: rawMode)
            copy.size = size
            copy.refresh = refresh
            copy.isPreferred = isPreferred
            copy.isFinished = isFinished
            return copy
        }
    }

    final class HeadState {
        let rawHead: RawWlrOutputHead
        var name: String?
        var description: String?
        var modes: [ObjectIdentifier: ModeState] = [:]
        var modeOrder: [ObjectIdentifier] = []
        var currentModeKey: ObjectIdentifier?
        var enabled = false
        var position: LogicalOffset?
        var scale: SurfaceScale?
        var transform: OutputTransform?
        var make: String?
        var model: String?
        var serialNumber: String?
        var isFinished = false

        init(rawHead outputHead: RawWlrOutputHead) {
            rawHead = outputHead
        }

        var currentMode: ModeState? {
            currentModeKey.flatMap { modes[$0] }
        }

        func copy() -> HeadState {
            let copy = HeadState(rawHead: rawHead)
            copy.name = name
            copy.description = description
            copy.modes = modes.mapValues { $0.copy() }
            copy.modeOrder = modeOrder
            copy.currentModeKey = currentModeKey
            copy.enabled = enabled
            copy.position = position
            copy.scale = scale
            copy.transform = transform
            copy.make = make
            copy.model = model
            copy.serialNumber = serialNumber
            copy.isFinished = isFinished
            return copy
        }
    }

    private let headIDProvider: (String?) -> OutputManagementHeadID
    private let modeIDProvider: (OutputManagementModeStableKey?) -> OutputManagementModeID
    private var serial: UInt32?
    private var committedStates: [ObjectIdentifier: HeadState] = [:]
    private var committedOrder: [ObjectIdentifier] = []
    private var pendingStates: [ObjectIdentifier: HeadState] = [:]
    private var pendingOrder: [ObjectIdentifier] = []
    private(set) var isFinished = false

    init(core displayCore: DisplayCore) {
        headIDProvider = { name in
            displayCore.outputManagementHeadID(for: name)
        }
        modeIDProvider = { key in
            displayCore.outputManagementModeID(for: key)
        }
    }

    init(
        headIDProvider outputHeadIDProvider: @escaping (String?) -> OutputManagementHeadID,
        modeIDProvider outputModeIDProvider: @escaping () -> OutputManagementModeID
    ) {
        headIDProvider = outputHeadIDProvider
        modeIDProvider = { _ in outputModeIDProvider() }
    }

    func handle(_ event: RawWlrOutputManagerEvent) {
        guard !isFinished else { return }

        switch event {
        case .head(let head):
            let key = ObjectIdentifier(head)
            pendingStates[key] = HeadState(rawHead: head)
            pendingOrder.append(key)
        case .headEvent(let head, let headEvent):
            handle(headEvent, for: ObjectIdentifier(head))
        case .modeEvent(let head, let mode, let modeEvent):
            handle(modeEvent, for: ObjectIdentifier(mode), headKey: ObjectIdentifier(head))
        case .done(let doneSerial):
            publishPendingState()
            serial = doneSerial
        case .finished:
            isFinished = true
        }
    }

    private func handle(_ event: RawWlrOutputHeadEvent, for key: ObjectIdentifier) {
        guard let state = pendingStates[key] else { return }

        switch event {
        case .name(let name):
            state.name = name
        case .description(let description):
            state.description = description
        case .physicalSize:
            break
        case .mode(let mode):
            addMode(mode, to: state)
        case .enabled(let enabled):
            state.enabled = enabled
        case .currentMode(let mode):
            state.currentModeKey = ObjectIdentifier(mode)
        case .position, .transform, .scale, .finished:
            updateLayout(event, state: state)
        case .make, .model, .serialNumber, .adaptiveSync:
            updateMetadata(event, state: state)
        case .modeEvent(let mode, let modeEvent):
            handle(modeEvent, for: ObjectIdentifier(mode), headKey: key)
        }
    }

    private func addMode(_ mode: RawWlrOutputMode, to state: HeadState) {
        let modeKey = ObjectIdentifier(mode)
        state.modes[modeKey] = ModeState(
            rawMode: mode
        )
        state.modeOrder.append(modeKey)
    }

    private func updateLayout(
        _ event: RawWlrOutputHeadEvent,
        state: HeadState
    ) {
        switch event {
        case .position(let x, let y):
            state.position = LogicalOffset(x: x, y: y)
        case .transform(let transform):
            state.transform = OutputTransform(rawValue: transform)
        case .scale(let scale):
            state.scale = SurfaceScale(scale)
        case .finished:
            state.isFinished = true
        default:
            break
        }
    }

    private func updateMetadata(
        _ event: RawWlrOutputHeadEvent,
        state: HeadState
    ) {
        switch event {
        case .make(let make):
            state.make = make
        case .model(let model):
            state.model = model
        case .serialNumber(let serialNumber):
            state.serialNumber = serialNumber
        default:
            break
        }
    }

    private func handle(
        _ event: RawWlrOutputModeEvent,
        for key: ObjectIdentifier,
        headKey: ObjectIdentifier
    ) {
        guard let mode = pendingStates[headKey]?.modes[key] else { return }

        switch event {
        case .size(let width, let height):
            do {
                mode.size = try PositivePixelSize(width: width, height: height)
            } catch {
                mode.size = nil
            }
        case .refresh(let refresh):
            if let outputRefresh = OutputRefreshRate(refresh) {
                mode.refresh = outputRefresh
            }
        case .preferred:
            mode.isPreferred = true
        case .finished:
            mode.isFinished = true
        }
    }

    func collection(manager: RawWlrOutputManager) throws -> OutputManagementCollection {
        let outputSnapshot = try snapshot()
        let activeStates = activeHeadStates()
        return OutputManagementCollection(
            manager: manager,
            snapshot: outputSnapshot,
            states: activeStates,
            collector: self
        )
    }

    func snapshot() throws -> OutputManagementSnapshot {
        guard let serial else {
            throw ClientError.display(.outputManagementIncomplete)
        }

        let activeStates = activeHeadStates()
        let heads = activeStates.map(snapshot(for:))
        return OutputManagementSnapshot(heads: heads, serial: serial)
    }

    private func activeHeadStates() -> [HeadState] {
        committedOrder.compactMap { committedStates[$0] }.filter { !$0.isFinished }
    }

    private func publishPendingState() {
        committedStates = pendingStates
        committedOrder = pendingOrder
        pendingStates = committedStates.mapValues { $0.copy() }
        pendingOrder = committedOrder
    }

    private func snapshot(for state: HeadState) -> OutputManagementHead {
        let headID = headIDProvider(state.name)
        let currentKey = state.currentModeKey
        let modes = state.modeOrder.compactMap { state.modes[$0] }
            .filter { !$0.isFinished }
            .map { mode in
                let key = OutputManagementModeStableKey(headID: headID, mode: mode)
                return OutputManagementMode(
                    id: modeIDProvider(key),
                    size: mode.size,
                    refresh: mode.refresh,
                    isPreferred: mode.isPreferred,
                    isCurrent: currentKey == ObjectIdentifier(mode.rawMode)
                )
            }
        return OutputManagementHead(
            id: headID,
            name: state.name,
            description: state.description,
            modes: modes,
            enabled: state.enabled,
            position: state.position,
            scale: state.scale,
            transform: state.transform,
            make: state.make,
            model: state.model,
            serialNumber: state.serialNumber
        )
    }
}

extension WaylandFixed {
    init(_ scale: SurfaceScale) {
        let raw = Int64(scale.numerator) * 256 / Int64(scale.denominator)
        self.init(rawValue: Int32(raw))
    }
}

extension SurfaceScale {
    init?(_ fixed: WaylandFixed) {
        guard fixed.rawValue > 0 else { return nil }

        do {
            try self.init(numerator: UInt32(fixed.rawValue), denominator: 256)
        } catch {
            return nil
        }
    }
}
