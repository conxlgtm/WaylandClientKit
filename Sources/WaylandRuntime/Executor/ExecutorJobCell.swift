@safe
final class ExecutorJobCell {
    private let storage: UnsafeMutablePointer<ExecutorJob>
    private nonisolated(unsafe) var containsJob = true

    init(_ job: consuming ExecutorJob) {
        storage = UnsafeMutablePointer<ExecutorJob>.allocate(capacity: 1)
        unsafe storage.initialize(to: job)
    }

    deinit {
        if containsJob {
            preconditionFailure("Executor job was dropped without running")
        }

        unsafe storage.deallocate()
    }

    func run(on executor: UnownedSerialExecutor) {
        precondition(containsJob, "Executor job already consumed")
        containsJob = false

        let job = unsafe storage.move()
        unsafe job.runSynchronously(on: executor)
    }
}
