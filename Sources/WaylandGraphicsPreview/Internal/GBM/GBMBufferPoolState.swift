package struct GBMBufferPoolSlotID: Hashable, Comparable, Sendable {
    package let rawValue: Int

    package init(_ value: Int) throws(GBMBufferPoolStateError) {
        guard value >= 0 else {
            throw GBMBufferPoolStateError.invalidSlotID(value)
        }

        rawValue = value
    }

    package static func < (lhs: GBMBufferPoolSlotID, rhs: GBMBufferPoolSlotID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

package enum GBMBufferPoolSlotLifecycle: Equatable, Sendable {
    case available
    case leased
    case submitted(commitGeneration: UInt64)
    case committedUntracked

    package var isAvailable: Bool {
        self == .available
    }

    package var isLeased: Bool {
        self == .leased
    }

    package var isInCompositorUse: Bool {
        submittedCommitGeneration != nil || self == .committedUntracked
    }

    package var submittedCommitGeneration: UInt64? {
        guard case .submitted(let generation) = self else {
            return nil
        }

        return generation
    }
}

package enum GBMBufferPoolStateError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidSlotID(Int)
    case duplicateSlot(GBMBufferPoolSlotID)
    case unknownSlot(GBMBufferPoolSlotID)
    case noAvailableSlots
    case slotNotAvailable(GBMBufferPoolSlotID, actual: GBMBufferPoolSlotLifecycle)
    case slotNotLeased(GBMBufferPoolSlotID, actual: GBMBufferPoolSlotLifecycle)
    case slotNotSubmitted(GBMBufferPoolSlotID, actual: GBMBufferPoolSlotLifecycle)
    case invalidCommitGeneration(UInt64)

    package var description: String {
        switch self {
        case .invalidSlotID(let rawValue):
            "invalid GBM buffer pool slot \(rawValue)"
        case .duplicateSlot(let slotID):
            "duplicate GBM buffer pool slot \(slotID.rawValue)"
        case .unknownSlot(let slotID):
            "unknown GBM buffer pool slot \(slotID.rawValue)"
        case .noAvailableSlots:
            "no GBM buffer pool slots are available"
        case .slotNotAvailable(let slotID, let actual):
            "GBM buffer pool slot \(slotID.rawValue) is \(actual), not available"
        case .slotNotLeased(let slotID, let actual):
            "GBM buffer pool slot \(slotID.rawValue) is \(actual), not leased"
        case .slotNotSubmitted(let slotID, let actual):
            "GBM buffer pool slot \(slotID.rawValue) is \(actual), not submitted"
        case .invalidCommitGeneration(let generation):
            "invalid GBM buffer pool commit generation \(generation)"
        }
    }
}

package struct GBMBufferPoolState: Equatable, Sendable {
    private var slots: [GBMBufferPoolSlotID: GBMBufferPoolSlotLifecycle] = [:]

    package init() {
        // Empty pool state is built up as buffers are allocated.
    }

    package var availableSlotIDs: [GBMBufferPoolSlotID] {
        slots.compactMap { slotID, lifecycle in
            lifecycle.isAvailable ? slotID : nil
        }.sorted()
    }

    package var slotIDs: [GBMBufferPoolSlotID] {
        slots.keys.sorted()
    }

    package var submittedSlotIDs: [GBMBufferPoolSlotID] {
        slots.compactMap { slotID, lifecycle in
            lifecycle.isInCompositorUse ? slotID : nil
        }.sorted()
    }

    package func lifecycle(
        for slotID: GBMBufferPoolSlotID
    ) throws(GBMBufferPoolStateError) -> GBMBufferPoolSlotLifecycle {
        guard let lifecycle = slots[slotID] else {
            throw GBMBufferPoolStateError.unknownSlot(slotID)
        }

        return lifecycle
    }

    package mutating func insertAvailableSlot(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GBMBufferPoolStateError) {
        guard slots[slotID] == nil else {
            throw GBMBufferPoolStateError.duplicateSlot(slotID)
        }

        slots[slotID] = .available
    }

    package mutating func removeAvailableSlots() -> [GBMBufferPoolSlotID] {
        let removedSlotIDs = availableSlotIDs
        for slotID in removedSlotIDs {
            slots[slotID] = nil
        }
        return removedSlotIDs
    }

    package mutating func leaseNextAvailableSlot()
        throws(GBMBufferPoolStateError) -> GBMBufferPoolSlotID
    {
        guard let slotID = availableSlotIDs.first else {
            throw GBMBufferPoolStateError.noAvailableSlots
        }

        slots[slotID] = .leased
        return slotID
    }

    package mutating func leaseAvailableSlot(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GBMBufferPoolStateError) -> GBMBufferPoolSlotID {
        let lifecycle = try lifecycle(for: slotID)
        guard lifecycle.isAvailable else {
            throw GBMBufferPoolStateError.slotNotAvailable(slotID, actual: lifecycle)
        }

        slots[slotID] = .leased
        return slotID
    }

    package mutating func markSubmitted(
        _ slotID: GBMBufferPoolSlotID,
        commitGeneration: UInt64
    ) throws(GBMBufferPoolStateError) {
        guard commitGeneration > 0 else {
            throw GBMBufferPoolStateError.invalidCommitGeneration(commitGeneration)
        }

        let lifecycle = try lifecycle(for: slotID)
        guard lifecycle.isLeased else {
            throw GBMBufferPoolStateError.slotNotLeased(slotID, actual: lifecycle)
        }

        slots[slotID] = .submitted(commitGeneration: commitGeneration)
    }

    package mutating func markCommittedUntracked(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GBMBufferPoolStateError) {
        _ = try lifecycle(for: slotID)
        slots[slotID] = .committedUntracked
    }

    package mutating func cancelLease(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GBMBufferPoolStateError) {
        let lifecycle = try lifecycle(for: slotID)
        guard lifecycle.isLeased else {
            throw GBMBufferPoolStateError.slotNotLeased(slotID, actual: lifecycle)
        }

        slots[slotID] = .available
    }

    package mutating func markReleased(
        _ slotID: GBMBufferPoolSlotID
    ) throws(GBMBufferPoolStateError) {
        let lifecycle = try lifecycle(for: slotID)
        guard lifecycle.isInCompositorUse else {
            throw GBMBufferPoolStateError.slotNotSubmitted(slotID, actual: lifecycle)
        }

        slots[slotID] = .available
    }
}
