@safe
final class ExecutorJobCell {
    private var job: ExecutorJob?

    init(_ job: consuming ExecutorJob) {
        self.job = consume job
    }

    deinit {
        precondition(job == nil, "Executor job was dropped without running")
    }

    func run(on executor: UnownedSerialExecutor) {
        guard let job = job.take() else {
            preconditionFailure("Executor job already consumed")
        }

        unsafe job.runSynchronously(on: executor)
    }
}
