import CWaylandProtocols

@safe
package final class OutputRegistry {
    @safe private let registry: OpaquePointer
    private let proxyAdoption: RawProxyAdoptionContext
    private let invariantFailureSink: RawInvariantFailureSink?
    private let xdgOutputManager: OptionalXDGOutputManager
    private var outputsByID: [RawOutputID: RawOutput] = [:]
    private var xdgOutputsByID: [RawOutputID: RawXDGOutput] = [:]
    private var pendingEvents: [RawOutputEvent] = []

    @safe
    init(
        registry rawRegistry: OpaquePointer,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil,
        xdgOutputManager optionalXDGOutputManager: OptionalXDGOutputManager = .missing
    ) {
        unsafe registry = rawRegistry
        proxyAdoption = adoptionContext
        invariantFailureSink = failureSink
        xdgOutputManager = optionalXDGOutputManager
    }

    package var snapshots: [RawOutputSnapshot] {
        outputsByID.values.map(\.snapshot).sorted { $0.id.rawValue < $1.id.rawValue }
    }

    package func bindOutputs(from globals: [RawGlobalAdvertisement]) throws {
        for global in globals where global.interfaceName == "wl_output" {
            try bindOutput(global)
        }
    }

    package func bindAdvertisedOutput(_ global: RawGlobalAdvertisement) throws {
        guard global.interfaceName == "wl_output" else { return }

        try bindOutput(global)
    }

    package func output(for id: RawOutputID) -> RawOutput? {
        outputsByID[id]
    }

    package func outputID(for pointerIdentity: RawOutputPointerIdentity) -> RawOutputID? {
        outputsByID.first { _, output in
            output.pointerIdentity == pointerIdentity
        }?.key
    }

    package func drainEvents() -> [RawOutputEvent] {
        defer { pendingEvents.removeAll(keepingCapacity: true) }
        return pendingEvents
    }

    package func removeOutput(globalName: UInt32) {
        let id = RawOutputID(rawValue: globalName)
        guard let output = outputsByID.removeValue(forKey: id) else { return }

        xdgOutputsByID.removeValue(forKey: id)?.destroy()
        output.destroy()
        pendingEvents.append(.removed(id))
    }

    package func destroy() {
        for xdgOutput in xdgOutputsByID.values {
            xdgOutput.destroy()
        }
        for output in outputsByID.values {
            output.destroy()
        }
        xdgOutputsByID.removeAll()
        outputsByID.removeAll()
    }

    private func bindOutput(_ global: RawGlobalAdvertisement) throws {
        let id = RawOutputID(rawValue: global.name)
        guard outputsByID[id] == nil else { return }

        let version = global.negotiatedVersion(supportedByClient: SupportedVersions.wlOutput)
        guard
            let pointer = unsafe swl_registry_bind_wl_output(
                registry,
                global.name,
                version.value
            )
        else {
            throw RuntimeError.bindFailed("wl_output")
        }

        let output = try RawOutput(
            id: id,
            pointer: pointer,
            version: version,
            proxyAdoption: proxyAdoption,
            invariantFailureSink: invariantFailureSink
        ) { [weak self] snapshot in
            self?.pendingEvents.append(.changed(snapshot))
        }

        do {
            if let manager = xdgOutputManager.boundObject {
                xdgOutputsByID[id] = try manager.getXDGOutput(for: output)
            }
            outputsByID[id] = output
        } catch {
            output.destroy()
            throw error
        }
    }

    deinit {
        destroy()
    }
}
