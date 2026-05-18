public enum SyncobjRequestRecordingGate {
    private static let state = SubmitRequestRecordingGateState()

    public static func withExclusiveRecording<T>(
        _ operation: () async throws -> T
    ) async throws -> T {
        await state.acquire()
        do {
            let value = try await operation()
            await state.release()
            return value
        } catch {
            await state.release()
            throw error
        }
    }
}

public enum FifoRequestRecordingGate {
    private static let state = SubmitRequestRecordingGateState()

    public static func withExclusiveRecording<T>(
        _ operation: () async throws -> T
    ) async throws -> T {
        await state.acquire()
        do {
            let value = try await operation()
            await state.release()
            return value
        } catch {
            await state.release()
            throw error
        }
    }
}

public enum CommitTimingRequestRecordingGate {
    private static let state = SubmitRequestRecordingGateState()

    public static func withExclusiveRecording<T>(
        _ operation: () async throws -> T
    ) async throws -> T {
        await state.acquire()
        do {
            let value = try await operation()
            await state.release()
            return value
        } catch {
            await state.release()
            throw error
        }
    }
}

private actor SubmitRequestRecordingGateState {
    private var isOccupied = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isOccupied {
            isOccupied = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            isOccupied = false
            return
        }

        let next = waiters.removeFirst()
        next.resume()
    }
}

