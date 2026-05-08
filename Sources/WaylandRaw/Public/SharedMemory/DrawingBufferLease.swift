package struct DrawingBufferLease: ~Copyable {
    private var isCompleted = false
    private let release: () -> Void
    private let markPendingRelease: (UInt64) -> Bool

    package init(
        release releaseBuffer: @escaping () -> Void,
        markPendingRelease commitBuffer: @escaping (UInt64) -> Bool
    ) {
        release = releaseBuffer
        markPendingRelease = commitBuffer
    }

    package var canWrite: Bool {
        !isCompleted
    }

    package func preconditionCanWrite() {
        precondition(!isCompleted, "drawing buffer cannot be written after completion")
    }

    package mutating func discard() {
        guard !isCompleted else { return }

        isCompleted = true
        release()
    }

    package mutating func markBusy(commitGeneration: UInt64) {
        precondition(!isCompleted, "drawing buffer cannot be committed more than once")
        isCompleted = true
        precondition(
            markPendingRelease(commitGeneration),
            "acquired drawing buffer must move to pending release"
        )
    }

    deinit {
        if !isCompleted {
            release()
        }
    }
}
