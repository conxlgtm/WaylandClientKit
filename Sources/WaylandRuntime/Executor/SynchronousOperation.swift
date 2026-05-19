import Glibc

@safe
final class SynchronousOperation<ResultValue: Sendable>: Sendable {
    private let operation: @Sendable () throws(WaylandThreadExecutorError) -> ResultValue
    nonisolated(unsafe) private var mutex = unsafe pthread_mutex_t()
    nonisolated(unsafe) private var condition = pthread_cond_t()
    nonisolated(unsafe) private var synchronizationPrimitivesAreLive = false
    nonisolated(unsafe) private var result: Result<ResultValue, WaylandThreadExecutorError>?

    init(
        _ body: @Sendable @escaping () throws(WaylandThreadExecutorError) -> ResultValue
    ) throws(WaylandThreadExecutorError) {
        operation = body

        let mutexResult = unsafe pthread_mutex_init(&mutex, nil)
        guard mutexResult == 0 else {
            throw WaylandThreadExecutorError.operationSyncInitFailed(
                function: "pthread_mutex_init",
                code: mutexResult
            )
        }

        let conditionResult = unsafe pthread_cond_init(&condition, nil)
        guard conditionResult == 0 else {
            unsafe pthread_mutex_destroy(&mutex)
            throw WaylandThreadExecutorError.operationSyncInitFailed(
                function: "pthread_cond_init",
                code: conditionResult
            )
        }

        unsafe synchronizationPrimitivesAreLive = true
    }

    deinit {
        guard unsafe synchronizationPrimitivesAreLive else { return }

        unsafe pthread_mutex_destroy(&mutex)
        unsafe pthread_cond_destroy(&condition)
    }

    func run() {
        let operationResult: Result<ResultValue, WaylandThreadExecutorError>
        do {
            operationResult = .success(try operation())
        } catch {
            operationResult = .failure(error)
        }

        unsafe pthread_mutex_lock(&mutex)
        unsafe result = operationResult
        unsafe pthread_cond_signal(&condition)
        unsafe pthread_mutex_unlock(&mutex)
    }

    func wait() throws(WaylandThreadExecutorError) -> ResultValue {
        unsafe pthread_mutex_lock(&mutex)
        while unsafe result == nil {
            unsafe pthread_cond_wait(&condition, &mutex)
        }

        guard let operationResult = unsafe result else {
            unsafe pthread_mutex_unlock(&mutex)
            throw WaylandThreadExecutorError.executorClosed
        }
        unsafe pthread_mutex_unlock(&mutex)

        switch operationResult {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
