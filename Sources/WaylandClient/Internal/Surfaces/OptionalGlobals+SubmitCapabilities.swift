import WaylandRaw

extension OptionalGlobals {
    package var surfaceSynchronizationCapability: SurfaceSynchronizationCapability {
        guard let manager = linuxDrmSyncobjManager.boundObject else {
            return .implicitOnly
        }

        return .explicitAvailable(version: manager.version)
    }

    package var surfacePacingCapability: SurfacePacingCapability {
        switch (fifoManager.boundObject?.version, commitTimingManager.boundObject?.version) {
        case (.some(let fifo), .some(let commitTiming)):
            .fifoAndCommitTiming(fifo: fifo, commitTiming: commitTiming)
        case (.some(let fifo), .none):
            .fifo(version: fifo)
        case (.none, .some(let commitTiming)):
            .commitTiming(version: commitTiming)
        case (.none, .none):
            .unavailable
        }
    }
}
