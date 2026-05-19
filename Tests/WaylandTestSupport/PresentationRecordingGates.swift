public enum PresentationRequestRecordingGate {
    private static let state = PresentationRecordingGateState()

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

public enum PresentationListenerRecordingGate {
    private static let state = PresentationRecordingGateState()

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

private actor PresentationRecordingGateState {
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
