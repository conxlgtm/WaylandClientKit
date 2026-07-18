import WaylandRaw

extension PrimarySelectionController {
    package func drainSourceSendRequests() -> [DataTransferSourceSendRequest] {
        selectionEngine.drainSourceSendRequests()
    }

    package func drainSourceWriteJobs() throws -> [DataTransferSourceWriteJob] {
        try DataTransferSourceSendLifecycle.makeWriteJobs(
            from: drainSourceSendRequests(),
            recordDiscardError: recordSourceSendDiscardError
        )
    }

    func closeSourceSendDescriptor(_ descriptor: Int32) throws {
        try DataTransferSourceSendLifecycle.closeCallbackDescriptor(
            descriptor,
            close: backend.closeFileDescriptor
        )
    }

    package func discardPendingSourceSendRequests(for sourceID: DataSourceID) {
        DataTransferSourceSendLifecycle.discardRequests(
            selectionEngine.removeSourceSendRequests(for: sourceID)
        ) { request, error in
            recordCallbackError(
                error,
                context: .primarySelectionSource(
                    request.sourceID.primarySelectionIdentity
                )
            )
        }
    }

    func discardAllPendingSourceSendRequests() {
        DataTransferSourceSendLifecycle.discardRequests(
            drainSourceSendRequests()
        ) { _, _ in
            // Discard-all runs during teardown, so pending close failures cannot be routed.
        }
    }

    private func recordSourceSendDiscardError(
        request: DataTransferSourceSendRequest,
        error: any Error
    ) {
        recordCallbackError(error, context: .sourceWrite(request.source.diagnosticSource))
    }
}
