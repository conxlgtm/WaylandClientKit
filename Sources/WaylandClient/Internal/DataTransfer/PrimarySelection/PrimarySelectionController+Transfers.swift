import WaylandRaw

extension PrimarySelectionController {
    package func drainSourceSendRequests() -> [DataTransferSourceSendRequest] {
        backend.preconditionIsOwnerThread()
        return pendingSourceSendRequests.drain()
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
        var remainingRequests: [DataTransferSourceSendRequest] = []
        for request in drainSourceSendRequests() {
            if request.source == .primarySelection(sourceID) {
                DataTransferSourceSendLifecycle.discardRequests(
                    CollectionOfOne(request)
                ) { request, error in
                    recordCallbackError(
                        error,
                        context: .primarySelectionSource(
                            request.sourceID.primarySelectionIdentity
                        )
                    )
                }
            } else {
                remainingRequests.append(request)
            }
        }

        pendingSourceSendRequests = remainingRequests
    }

    func discardAllPendingSourceSendRequests() {
        DataTransferSourceSendLifecycle.discardRequests(
            drainSourceSendRequests()
        ) { _, _ in
            // Discard-all runs during teardown; pending close failures cannot be routed.
        }
    }

    private func recordSourceSendDiscardError(
        request: DataTransferSourceSendRequest,
        error: any Error
    ) {
        recordCallbackError(error, context: .sourceWrite(request.source.diagnosticSource))
    }
}
