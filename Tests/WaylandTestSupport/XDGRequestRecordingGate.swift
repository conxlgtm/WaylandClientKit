public enum XDGRequestRecordingGate {
    private static let state = ExclusiveGateState()

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

private actor ExclusiveGateState {
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
