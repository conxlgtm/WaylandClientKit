package enum RawOutputCoreEvent: Equatable, Sendable {
    case geometry(RawOutputGeometry)
    case mode(RawOutputMode)
    case done
    case scale(Int32)
    case name(String)
    case description(String)
}

package enum RawXDGOutputEvent: Equatable, Sendable {
    case logicalPosition(x: Int32, y: Int32)
    case logicalSize(width: Int32, height: Int32)
    case done
    case name(String)
    case description(String)
}

private struct RawOutputLogicalPosition {
    let x: Int32
    let y: Int32
}

private struct RawOutputLogicalSize {
    let width: Int32
    let height: Int32
}

private enum RawOutputDescriptionSource {
    case wlOutput
    case xdgOutput
}

package struct RawOutputState {
    private var geometry: RawOutputGeometry?
    private var logicalPosition: RawOutputLogicalPosition?
    private var logicalSize: RawOutputLogicalSize?
    private var currentMode: RawOutputMode?
    private var scale: Int32 = 1
    private var name: String?
    private var description: String?
    private var descriptionSource: RawOutputDescriptionSource?

    package init() {
        // wl_output scale defaults to 1 until a valid scale event arrives.
    }

    private var logicalGeometry: RawOutputLogicalGeometry? {
        guard
            let logicalPosition,
            let logicalSize,
            logicalSize.width > 0,
            logicalSize.height > 0
        else {
            return nil
        }

        return RawOutputLogicalGeometry(
            x: logicalPosition.x,
            y: logicalPosition.y,
            width: logicalSize.width,
            height: logicalSize.height
        )
    }

    package func snapshot(id: RawOutputID, version: RawVersion) -> RawOutputSnapshot {
        RawOutputSnapshot(
            id: id,
            version: version,
            geometry: geometry,
            logicalGeometry: logicalGeometry,
            currentMode: currentMode,
            scale: scale,
            name: name,
            description: description
        )
    }

    package mutating func applyCoreEvent(
        _ event: RawOutputCoreEvent,
        version: RawVersion
    ) -> Bool {
        switch event {
        case .geometry(let geometry):
            self.geometry = geometry
            return publishesWithoutDoneEvent(version: version)
        case .mode(let mode):
            guard mode.flags & 0x1 != 0 else { return false }
            guard mode.isValidCurrentMode else {
                currentMode = nil
                return publishesWithoutDoneEvent(version: version)
            }
            currentMode = mode
            return publishesWithoutDoneEvent(version: version)
        case .done:
            return true
        case .scale(let scale):
            guard scale > 0 else { return false }
            self.scale = scale
            return publishesWithoutDoneEvent(version: version)
        case .name(let name):
            self.name = name.isEmpty ? nil : name
            return publishesWithoutDoneEvent(version: version)
        case .description(let description):
            self.description = description.isEmpty ? nil : description
            descriptionSource = .wlOutput
            return publishesWithoutDoneEvent(version: version)
        }
    }

    package mutating func applyXDGOutputEvent(
        _ event: RawXDGOutputEvent,
        outputVersion: RawVersion,
        xdgOutputVersion: RawVersion
    ) -> Bool {
        switch event {
        case .logicalPosition(let x, let y):
            logicalPosition = RawOutputLogicalPosition(x: x, y: y)
            return publishesXDGOutputEventWithoutDoneEvent(
                outputVersion: outputVersion,
                xdgOutputVersion: xdgOutputVersion
            )
        case .logicalSize(let width, let height):
            guard width > 0, height > 0 else {
                logicalSize = nil
                return publishesXDGOutputEventWithoutDoneEvent(
                    outputVersion: outputVersion,
                    xdgOutputVersion: xdgOutputVersion
                )
            }
            logicalSize = RawOutputLogicalSize(width: width, height: height)
            return publishesXDGOutputEventWithoutDoneEvent(
                outputVersion: outputVersion,
                xdgOutputVersion: xdgOutputVersion
            )
        case .done:
            return true
        case .name(let name):
            if self.name == nil {
                self.name = name.isEmpty ? nil : name
            }
            return publishesXDGOutputEventWithoutDoneEvent(
                outputVersion: outputVersion,
                xdgOutputVersion: xdgOutputVersion
            )
        case .description(let description):
            guard descriptionSource != .wlOutput else {
                return publishesXDGOutputEventWithoutDoneEvent(
                    outputVersion: outputVersion,
                    xdgOutputVersion: xdgOutputVersion
                )
            }

            self.description = description.isEmpty ? nil : description
            descriptionSource = .xdgOutput
            return publishesXDGOutputEventWithoutDoneEvent(
                outputVersion: outputVersion,
                xdgOutputVersion: xdgOutputVersion
            )
        }
    }

    private func publishesWithoutDoneEvent(version: RawVersion) -> Bool {
        version < RawVersion(2)
    }

    private func publishesXDGOutputEventWithoutDoneEvent(
        outputVersion: RawVersion,
        xdgOutputVersion: RawVersion
    ) -> Bool {
        outputVersion < RawVersion(2) && xdgOutputVersion >= RawVersion(3)
    }
}
