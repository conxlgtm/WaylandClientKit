package enum BufferRetirementReason: Equatable, Sendable {
    case resized
    case windowClosed
    case destroyed
}

package enum BufferLifecycle: Equatable, Sendable {
    case available
    case acquiredForDrawing
    case pendingRelease(commitGeneration: UInt64)
    case retired(reason: BufferRetirementReason, pendingReleaseGeneration: UInt64?)
}

package struct BufferBusyState: Equatable, Sendable {
    package private(set) var lifecycle = BufferLifecycle.available

    package var isBusy: Bool {
        switch lifecycle {
        case .acquiredForDrawing, .pendingRelease:
            true
        case .retired(_, let pendingReleaseGeneration):
            pendingReleaseGeneration != nil
        case .available:
            false
        }
    }

    package var isReusable: Bool {
        lifecycle == .available
    }

    package init() {
        // Start reusable until the buffer is attached for presentation.
    }

    @discardableResult
    package mutating func acquireForDrawing() -> Bool {
        guard lifecycle == .available else {
            return false
        }

        lifecycle = .acquiredForDrawing
        return true
    }

    package mutating func markPendingRelease(commitGeneration: UInt64) {
        lifecycle = .pendingRelease(commitGeneration: commitGeneration)
    }

    package mutating func markReleased() {
        switch lifecycle {
        case .retired(let reason, .some):
            lifecycle = .retired(reason: reason, pendingReleaseGeneration: nil)
        case .retired:
            break
        case .available, .acquiredForDrawing, .pendingRelease:
            lifecycle = .available
        }
    }

    package mutating func markRetired(reason: BufferRetirementReason) {
        switch lifecycle {
        case .pendingRelease(let commitGeneration):
            lifecycle = .retired(
                reason: reason,
                pendingReleaseGeneration: commitGeneration
            )
        case .retired:
            break
        case .available, .acquiredForDrawing:
            lifecycle = .retired(reason: reason, pendingReleaseGeneration: nil)
        }
    }
}
