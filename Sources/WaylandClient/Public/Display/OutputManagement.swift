public enum OutputManagementProtocolFamily: Equatable, Sendable {
    case wlrootsUnstableV1
}

public struct OutputHeadID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt32

    public init(rawValue headRawValue: UInt32) {
        rawValue = headRawValue
    }

    package init(_ outputID: OutputID) {
        rawValue = outputID.rawValue
    }

    public var description: String {
        "output-head-\(rawValue)"
    }
}

public struct OutputHead: Equatable, Sendable, Identifiable {
    public let id: OutputHeadID
    public let name: String?
    public let description: String?
    public let modes: [OutputMode]
    public let enabled: Bool
    public let position: LogicalOffset?
    public let scale: SurfaceScale?
    public let transform: OutputTransform?

    public init(
        id headID: OutputHeadID,
        name headName: String?,
        description headDescription: String?,
        modes headModes: [OutputMode],
        enabled headEnabled: Bool,
        position headPosition: LogicalOffset?,
        scale headScale: SurfaceScale?,
        transform headTransform: OutputTransform?
    ) {
        id = headID
        name = headName
        description = headDescription
        modes = headModes
        enabled = headEnabled
        position = headPosition
        scale = headScale
        transform = headTransform
    }

    package init(_ output: OutputSnapshot) {
        self.init(
            id: OutputHeadID(output.id),
            name: output.name,
            description: output.description,
            modes: output.currentMode.map { [$0] } ?? [],
            enabled: true,
            position: output.logicalGeometry.map { LogicalOffset(x: $0.x, y: $0.y) },
            scale: try? SurfaceScale(integerScale: output.scale.rawValue),
            transform: output.geometry?.transform
        )
    }
}

public struct OutputManagementSnapshot: Equatable, Sendable {
    public let protocolFamily: OutputManagementProtocolFamily
    public let heads: [OutputHead]

    public init(
        protocolFamily snapshotProtocolFamily: OutputManagementProtocolFamily,
        heads snapshotHeads: [OutputHead]
    ) {
        protocolFamily = snapshotProtocolFamily
        heads = snapshotHeads
    }
}

public struct OutputConfigurationProposal: Equatable, Sendable {
    public let snapshot: OutputManagementSnapshot

    public init(current snapshot: OutputManagementSnapshot) {
        self.snapshot = snapshot
    }
}

extension WaylandDisplay {
    public func outputManagementSnapshot() throws -> OutputManagementSnapshot {
        guard try capabilities().outputManagement.isAvailable else {
            throw ClientError.display(.outputManagementUnavailable)
        }

        return OutputManagementSnapshot(
            protocolFamily: .wlrootsUnstableV1,
            heads: try outputTopology().map(OutputHead.init)
        )
    }

    public func testOutputConfiguration(
        _ proposal: OutputConfigurationProposal
    ) throws {
        try validateOutputConfigurationProposal(proposal)
        throw ClientError.display(
            .unsupportedOutputConfigurationOperation(
                "wlr-output-management test requires manager serial events"
            )
        )
    }

    public func applyOutputConfiguration(
        _ proposal: OutputConfigurationProposal
    ) throws {
        try validateOutputConfigurationProposal(proposal)
        throw ClientError.display(
            .unsupportedOutputConfigurationOperation(
                "wlr-output-management apply requires manager serial events"
            )
        )
    }

    private func validateOutputConfigurationProposal(
        _ proposal: OutputConfigurationProposal
    ) throws {
        let current = try outputManagementSnapshot()
        guard current.heads.map(\.id) == proposal.snapshot.heads.map(\.id) else {
            throw ClientError.display(.staleOutputConfiguration)
        }
    }
}
