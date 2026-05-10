import CWaylandProtocols

@safe
package final class OutputRegistry {
    @safe private let registry: OpaquePointer
    private let proxyAdoption: RawProxyAdoptionContext
    private let invariantFailureSink: RawInvariantFailureSink?
    private var outputsByID: [RawOutputID: RawOutput] = [:]

    @safe
    init(
        registry rawRegistry: OpaquePointer,
        proxyAdoption adoptionContext: RawProxyAdoptionContext,
        invariantFailureSink failureSink: RawInvariantFailureSink? = nil
    ) {
        unsafe registry = rawRegistry
        proxyAdoption = adoptionContext
        invariantFailureSink = failureSink
    }

    package var snapshots: [RawOutputSnapshot] {
        outputsByID.values.map(\.snapshot).sorted { $0.id.rawValue < $1.id.rawValue }
    }

    package func bindOutputs(from globals: [RawGlobalAdvertisement]) throws {
        for global in globals where global.interfaceName == "wl_output" {
            try bindOutput(global)
        }
    }

    package func removeOutput(globalName: UInt32) {
        let id = RawOutputID(rawValue: globalName)
        outputsByID.removeValue(forKey: id)?.destroy()
    }

    package func destroy() {
        for output in outputsByID.values {
            output.destroy()
        }
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

        outputsByID[id] = try RawOutput(
            id: id,
            pointer: pointer,
            version: version,
            proxyAdoption: proxyAdoption,
            invariantFailureSink: invariantFailureSink
        )
    }

    deinit {
        destroy()
    }
}
