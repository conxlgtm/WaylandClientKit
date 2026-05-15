import WaylandRaw

package typealias WindowOutputMembershipState = SurfaceOutputMembershipState

package struct SurfaceOutputMembershipState: Equatable, Sendable {
    private var outputIDs: Set<RawOutputID> = []

    package init() {
        // Starts with no compositor output membership.
    }

    package mutating func enter(_ outputID: RawOutputID) -> Bool {
        outputIDs.insert(outputID).inserted
    }

    package mutating func leave(_ outputID: RawOutputID) -> Bool {
        outputIDs.remove(outputID) != nil
    }

    package mutating func remove(_ outputID: OutputID) -> Bool {
        outputIDs.remove(RawOutputID(outputID)) != nil
    }

    package func currentOutputIDs(
        where isStillBound: (RawOutputID) -> Bool = { _ in true }
    ) -> [OutputID] {
        outputIDs
            .filter(isStillBound)
            .map { OutputID($0) }
            .sortedByRawValue()
    }
}
