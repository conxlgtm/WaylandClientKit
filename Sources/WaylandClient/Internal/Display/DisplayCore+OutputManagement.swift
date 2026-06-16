import WaylandRaw

extension DisplayCore {
    func outputManagementSnapshot(
        timeoutMilliseconds: Int32
    ) throws -> OutputManagementSnapshot {
        try withFatalFailureFinalization {
            let session = try requireSession()
            let collection = try collectOutputManagement(
                session: session,
                timeoutMilliseconds: timeoutMilliseconds
            )
            defer { collection.destroy() }

            return collection.snapshot
        }
    }

    func testOutputConfiguration(
        _ proposal: OutputConfigurationProposal,
        timeoutMilliseconds: Int32
    ) throws {
        try runCurrentOutputConfiguration(
            proposal,
            timeoutMilliseconds: timeoutMilliseconds,
            apply: false
        )
    }

    func applyOutputConfiguration(
        _ proposal: OutputConfigurationProposal,
        timeoutMilliseconds: Int32
    ) throws {
        try runCurrentOutputConfiguration(
            proposal,
            timeoutMilliseconds: timeoutMilliseconds,
            apply: true
        )
    }

    func outputManagementHeadID(for name: String?) -> OutputManagementHeadID {
        guard let name else {
            return outputManagementHeadIDs.next()
        }

        if let existing = outputManagementHeadIDsByName[name] {
            return existing
        }

        let id = outputManagementHeadIDs.next()
        outputManagementHeadIDsByName[name] = id
        return id
    }

    func nextOutputManagementModeID() -> OutputManagementModeID {
        outputManagementModeIDs.next()
    }

    private func runCurrentOutputConfiguration(
        _ proposal: OutputConfigurationProposal,
        timeoutMilliseconds: Int32,
        apply shouldApply: Bool
    ) throws {
        let session = try requireSession()
        let collection = try collectOutputManagement(
            session: session,
            timeoutMilliseconds: timeoutMilliseconds
        )
        defer { collection.destroy() }

        guard collection.snapshot.serial == proposal.snapshot.serial else {
            throw ClientError.display(.staleOutputConfiguration)
        }

        var result: RawWlrOutputConfigurationEvent?
        let configuration = try collection.manager.createConfiguration(
            serial: collection.snapshot.serial
        ) { event in
            result = event
        }
        defer { configuration.destroy() }

        try collection.configureCurrentState(on: configuration)
        if shouldApply {
            configuration.apply()
        } else {
            configuration.test()
        }
        try session.connection.completeInitialDiscovery(
            timeoutMilliseconds: timeoutMilliseconds
        )

        switch result {
        case .succeeded:
            return
        case .failed:
            throw ClientError.display(.outputConfigurationFailed)
        case .cancelled:
            throw ClientError.display(.outputConfigurationCancelled)
        case nil:
            throw ClientError.display(.outputConfigurationFailed)
        }
    }

    private func collectOutputManagement(
        session: DisplaySession,
        timeoutMilliseconds: Int32
    ) throws -> OutputManagementCollection {
        let collector = OutputManagementCollector(core: self)
        guard
            let manager = try session.connection.bindWlrOutputManagerOneShot(
                onEvent: collector.handle
            )
        else {
            throw ClientError.display(.outputManagementUnavailable)
        }

        do {
            try session.connection.completeInitialDiscovery(
                timeoutMilliseconds: timeoutMilliseconds
            )
            return collector.collection(manager: manager)
        } catch {
            manager.destroy()
            throw error
        }
    }
}

private final class OutputManagementCollection {
    let manager: RawWlrOutputManager
    let snapshot: OutputManagementSnapshot
    private let states: [OutputManagementCollector.HeadState]

    init(
        manager outputManager: RawWlrOutputManager,
        snapshot outputSnapshot: OutputManagementSnapshot,
        states outputStates: [OutputManagementCollector.HeadState]
    ) {
        manager = outputManager
        snapshot = outputSnapshot
        states = outputStates
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
}

private final class OutputManagementCollector {
    final class ModeState {
        let id: OutputManagementModeID
        let rawMode: RawWlrOutputMode
        var size: PositivePixelSize?
        var refresh: OutputRefreshRate = .unspecified
        var isPreferred = false
        var isFinished = false

        init(id modeID: OutputManagementModeID, rawMode outputMode: RawWlrOutputMode) {
            id = modeID
            rawMode = outputMode
        }

        var snapshot: OutputManagementMode {
            OutputManagementMode(
                id: id,
                size: size,
                refresh: refresh,
                isPreferred: isPreferred,
                isCurrent: false
            )
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
    }

    private unowned let core: DisplayCore
    private var serial: UInt32?
    private var states: [ObjectIdentifier: HeadState] = [:]
    private var order: [ObjectIdentifier] = []

    init(core displayCore: DisplayCore) {
        core = displayCore
    }

    func handle(_ event: RawWlrOutputManagerEvent) {
        switch event {
        case .head(let head):
            let key = ObjectIdentifier(head)
            states[key] = HeadState(rawHead: head)
            order.append(key)
        case .headEvent(let head, let headEvent):
            handle(headEvent, for: ObjectIdentifier(head))
        case .modeEvent(let head, let mode, let modeEvent):
            handle(modeEvent, for: ObjectIdentifier(mode), headKey: ObjectIdentifier(head))
        case .done(let doneSerial):
            serial = doneSerial
        case .finished:
            break
        }
    }

    private func handle(_ event: RawWlrOutputHeadEvent, for key: ObjectIdentifier) {
        guard let state = states[key] else { return }

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
            id: core.nextOutputManagementModeID(),
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
        guard let mode = states[headKey]?.modes[key] else { return }

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

    func collection(manager: RawWlrOutputManager) -> OutputManagementCollection {
        let activeStates = order.compactMap { states[$0] }.filter { !$0.isFinished }
        let heads = activeStates.map { state in
            let currentID = state.currentMode?.id
            let modes = state.modeOrder.compactMap { state.modes[$0] }
                .filter { !$0.isFinished }
                .map { mode in
                    OutputManagementMode(
                        id: mode.id,
                        size: mode.size,
                        refresh: mode.refresh,
                        isPreferred: mode.isPreferred,
                        isCurrent: mode.id == currentID
                    )
                }
            return OutputManagementHead(
                id: core.outputManagementHeadID(for: state.name),
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
        let snapshot = OutputManagementSnapshot(heads: heads, serial: serial ?? 0)
        return OutputManagementCollection(
            manager: manager,
            snapshot: snapshot,
            states: activeStates
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
