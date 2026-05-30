public enum DesktopRequestRecordingGate {
    private static let state = DesktopRequestRecordingGateState()

    public static func withExclusiveRecording<Result: Sendable>(
        _ body: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        try await state.withExclusiveRecording(body)
    }
}

private actor DesktopRequestRecordingGateState {
    func withExclusiveRecording<Result: Sendable>(
        _ body: @Sendable () async throws -> Result
    ) async rethrows -> Result {
        try await body()
    }
}
