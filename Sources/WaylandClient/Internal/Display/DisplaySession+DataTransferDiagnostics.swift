extension DisplaySession {
    package static func dataTransferDiagnostic(
        from result: DataTransferSourceWriteResult
    ) -> DataTransferDiagnostic? {
        guard case .failed(let source, let mimeType, let error) = result,
            error != .cancelled
        else {
            return nil
        }

        return DataTransferDiagnostic(
            source: source.diagnosticSource,
            mimeType: mimeType,
            operation: .sourceWriteFailed,
            error: error
        )
    }
}
