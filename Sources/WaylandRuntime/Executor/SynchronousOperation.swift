import Glibc

@safe
final class SynchronousOperation<ResultValue: Sendable>: Sendable {
    private let operation: @Sendable () throws -> ResultValue
    private nonisolated(unsafe) var mutex = unsafe pthread_mutex_t()
    private nonisolated(unsafe) var condition = pthread_cond_t()
    private nonisolated(unsafe) var result: Result<ResultValue, Error>?

    init(_ body: @Sendable @escaping () throws -> ResultValue) {
        operation = body
        unsafe pthread_mutex_init(&mutex, nil)
        unsafe pthread_cond_init(&condition, nil)
    }

    deinit {
        unsafe pthread_mutex_destroy(&mutex)
        unsafe pthread_cond_destroy(&condition)
    }

    func run() {
        let operationResult = Result {
            try operation()
        }

        unsafe pthread_mutex_lock(&mutex)
        unsafe result = operationResult
        unsafe pthread_cond_signal(&condition)
        unsafe pthread_mutex_unlock(&mutex)
    }

    func wait() throws -> ResultValue {
        unsafe pthread_mutex_lock(&mutex)
        while unsafe result == nil {
            unsafe pthread_cond_wait(&condition, &mutex)
        }

        let operationResult = unsafe result
        unsafe pthread_mutex_unlock(&mutex)

        return try operationResult?.get()
            ?? { throw WaylandThreadExecutorError.executorClosed }()
    }
}
